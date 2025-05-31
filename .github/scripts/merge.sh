#!/usr/bin/env bash

merge () {
  ATTEMPT=1

  create_initial_comment
  ensure_pr_checks_pass

  for i in {1..3}; do
    ATTEMPT=$i

    unset SHOULD_RETRY

    create_merge_branch

    wait_for_ci_result
    if [[ -n "${SHOULD_RETRY:-}" ]]; then
      continue
    fi

    handle_ci_result

    wait_until_first_in_queue
    if [[ -n "${SHOULD_RETRY:-}" ]]; then
      continue
    fi

    merge_to_main
    return 0
  done
}

create_initial_comment () {
  echo "create_initial_comment"
  # --init because this is the initial comment, all following comments
  # will update this instance
  happy_update "🌱 Initialising merging process..." --init
}

ensure_pr_checks_pass () {
  echo "ensure_pr_checks_pass"
  merge_state_status="$(
    gh pr view $PR_NUMBER --repo $PROJECT_REPO --json mergeStateStatus |
    jq --raw-output '.mergeStateStatus'
  )"

  if [[ "$merge_state_status" != "CLEAN" ]]; then
    sad_update "✋ Github does not think this PR is mergeable"
    exit 0
  fi
}

set_merge_branch_properties () {
  echo "set_merge_branch_properties"
  happy_update "🧐 Checking current merge queue..."

  lock_merge_queue

  cd $GITHUB_WORKSPACE/merge-queue-state

  local pr_json="$(
    gh pr view $PR_NUMBER \
       --repo $PROJECT_REPO \
       --json title,headRefName,headRefOid
  )"
  PR_TITLE="$(echo $pr_json | jq --raw-output '.title')"
  PR_BRANCH="$(echo $pr_json | jq --raw-output '.headRefName')"
  PR_SHA="$(echo $pr_json | jq --raw-output '.headRefOid')"

  BRANCH_COUNTER=$(($(jq '.branchCounter' state.json) + 1))


  BASE_BRANCH="$(
    cat state.json |
    jq --raw-output \
       '.mergeBranches | map(select(.status != "failed")) | max_by(.count) | .name'
  )"
  if [[ "$BASE_BRANCH" == "null" ]]; then
    BASE_BRANCH=main
  fi

  MERGE_BRANCH=merge-branch/$PR_BRANCH-$BRANCH_COUNTER

  unlock_merge_queue

  cat "$GITHUB_ENV"
  echo "MERGE_BRANCH=$MERGE_BRANCH" >> "$GITHUB_ENV"
  cat "$GITHUB_ENV"
}

create_merge_branch () {
  echo "create_merge_branch"
  lock_merge_queue

  set_merge_branch_properties

  cd $GITHUB_WORKSPACE/project

  git fetch origin $BASE_BRANCH $PR_BRANCH
  git checkout $BASE_BRANCH && git pull

  git checkout -b $MERGE_BRANCH
  git checkout $PR_BRANCH && git reset --hard origin/$PR_BRANCH

  git rebase $MERGE_BRANCH

  git merge --no-edit --no-ff $PR_BRANCH
  git push --set-upstream origin HEAD:$MERGE_BRANCH

  MERGE_BRANCH_SHA=$(git rev-parse HEAD)

  cd $GITHUB_WORKSPACE/merge-queue-state

  # Need to keep a track of our ancestors so we know where we are in the queue
  if [[ "$BASE_BRANCH" == "main" ]]; then
    local ancestors=[]
  else
    local ancestors=$(
      cat state.json |
      jq --arg name "$BASE_BRANCH" \
          '.mergeBranches[] | select(.name == $name) | .ancestors | . += [$name]'
    )
  fi

  local state="$(
    cat state.json |
    jq --arg name "$MERGE_BRANCH" \
       --arg pr_number "$PR_NUMBER" \
       --arg sha "$MERGE_BRANCH_SHA" \
       --arg title "$PR_TITLE" \
       --arg status "running" \
       --argjson count $BRANCH_COUNTER \
       --argjson ancestors "$ancestors" \
       '.mergeBranches += [{ name: $name, title: $title, pr_number: $pr_number, sha: $sha, status: $status, count: $count, ancestors: $ancestors }]'
  )"

  state="$(echo $state | jq --argjson count $BRANCH_COUNTER '.branchCounter = $count')"

  if [[ -n "$state" ]]; then
    echo "$state" > state.json
    git add state.json
    git commit -m 'Updating merge state'
    git push
  else
    # TODO: can we fail safely from this?
    sad_ending "💣 - Error saving to merge queue state"
  fi

  happy_update "🦤 🦃 🦆 Joining the queue..."

  unlock_merge_queue
}

wait_for_ci_result () {
  echo "wait_for_ci_result"
  local ci_link="https://app.circleci.com/pipelines/github/$PROJECT_REPO?branch=$MERGE_BRANCH"

  # Check 80 times at 15 minute intervals - 20 minutes wait
  for i in {1..80}; do
    ensure_pr_still_mergeable
    if [[ -n "${SHOULD_RETRY:-}" ]]; then
      return 0
    fi

    local ci_state=$(
      gh api repos/$PROJECT_REPO/commits/$MERGE_BRANCH_SHA/status |
      jq --raw-output '.state'
    )

    if [[ "$ci_state" == "success" || "$ci_state" == "failure" ]]; then
      CI_RESULT=$ci_state
      return 0
    fi

    happy_update "🤞 Waiting on [CI result]($ci_link)..."

    sleep 15
  done

  sad_ending "💀 Timed out waiting for CI result"
}

handle_ci_result () {
  echo "handle_ci_result"
  lock_merge_queue

  cd $GITHUB_WORKSPACE/merge-queue-state

  if [[ "$CI_RESULT" == "success" ]]; then
    local branch_status="succeeded"
    happy_update "🟢 CI passed..."
  elif [[ "$CI_RESULT" == "failure" ]]; then
    # CI is a failure, but unless we're front of the queue we don't know
    # if we're the bad egg, so we won't remove ourselves until we know
    # We do know that none of our descendants will be passing though so
    # remove them
    sad_update "😔 CI failed, checking if this is us or a PR ahead in the queue..."
    local branch_status="failed"
    remove_descendants_from_queue
  else
    sad_ending "💣 Error - unknown result from CI, aborting"
  fi

  jq --arg name "$MERGE_BRANCH" \
     --arg branch_status "$branch_status" \
     '.mergeBranches |= map(if .name == $name then .status = $branch_status else . end)' \
     state.json > temp && mv temp state.json

  unlock_merge_queue
}

wait_until_first_in_queue () {
  echo "wait_until_first_queue"
  cd $GITHUB_WORKSPACE/merge-queue-state

  for i in {1..12}; do
    ensure_pr_still_mergeable
    if [[ -n "${SHOULD_RETRY:-}" ]]; then
      return 0
    fi

    # if we're the first branch we need to do something
    local first_branch=$(
      cat state.json |
        jq --raw-output '.mergeBranches | min_by(.count) | .name'
          )

    if [[ "$MERGE_BRANCH" == "$first_branch" ]]; then
      # LFG
      return 0
    fi

    happy_update "⏳ Waiting to reach the front of the queue..."

    sleep 5
  done

  sad_ending "💀 Timed out waiting to get to the front of the queue"
}

merge_to_main () {
  echo "merge_to_main"

  ensure_pr_still_mergeable
  if [[ -n "${SHOULD_RETRY:-}" ]]; then
    return 0
  fi

  lock_merge_queue

  cd $GITHUB_WORKSPACE/merge-queue-state

  # We've reached the front of the queue, but what's our status?
  local branch_status=$(
    cat state.json |
    jq --raw-output \
        --arg name "$MERGE_BRANCH" \
        '.mergeBranches[] | select(.name == $name) | .status'
  )

  # If there's no one in front of us and we're a failure then we must be a very
  # bad egg indeed and should leave the process.
  if [[ "$branch_status" == "failed" ]]; then
    local ci_link="https://app.circleci.com/pipelines/github/$PROJECT_REPO?branch=$MERGE_BRANCH"
    sad_ending "⛔ We’re front of the queue and CI has [failed]($ci_link), we can’t merge"
  fi

  # final check that the sha we are merging is correct
  cd $GITHUB_WORKSPACE/project
  git checkout $PR_BRANCH
  git fetch origin $PR_BRANCH
  git reset --hard origin/$PR_BRANCH

  if [[ "$PR_SHA" != "$(git rev-parse HEAD)" ]]; then
    sad_ending "🙃 The PR has been updated since the merge started, halting process"
  fi

  # We're are the front, we're not a failure, we can merge!
  happy_update "🙌 Ready to merge..."

  git fetch origin main
  git rebase origin/main
  git push --force-with-lease origin HEAD:$PR_BRANCH

  # TODO: Have a better way of checking this than an arbitrary sleep. If
  # we do the merge too soon the PR "closes" rather than "merges". The
  # result is the same for the code but it's not a nice end state.
  sleep 5

  git checkout main && git pull
  git merge $PR_BRANCH --no-ff
  git push

  happy_update "✅ Merged"

  remove_branch_from_queue

  unlock_merge_queue

  # delete the branch once the PR is in a merged state
  for i in {1..10}; do
    if [[ "$(gh pr view $PR_NUMBER --repo $PROJECT_REPO --json state --jq '.state')" == "MERGED" ]]; then
      # delete the PR branch
      git push --delete origin $PR_BRANCH
      exit 0
    fi

    sleep 2
  done
}
