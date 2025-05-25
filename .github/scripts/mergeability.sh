#!/usr/bin/env bash

ensure_pr_still_mergeable () {
  local starting_dir=$(pwd)

  # ensure PR hasn't been updated since we joined the queue
  if [[ "$PR_SHA" != "$(gh pr view $PR_NUMBER --repo $PROJECT_REPO --json headRefOid --jq '.headRefOid')" ]]; then
    sad_update "🙃 The PR has been updated since the merge started, halting process"
    remove_branch_from_queue
    remove_descendants_from_queue

    exit 1
  fi

  # Check we're still in the queue. If we're not it means an ancestor has failed
  # so we would too
  cd $GITHUB_WORKSPACE/merge-queue-state
  git pull

  branch=$(
    cat state.json |
    jq --arg name "$MERGE_BRANCH" \
       '.mergeBranches[] | select(.name == $name)'
  )

  if [ -z "$branch" ]; then
    sad_update "👎 Bad luck, an earlier PR in the queue has failed, please try again"
    remove_branch_from_queue
    remove_descendants_from_queue

    exit 1
  fi

  cd $starting_dir
}
