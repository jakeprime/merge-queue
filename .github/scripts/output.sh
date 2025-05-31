#!/usr/bin/env bash

# A happy update will include the merge queue, if there is one
happy_update () {
  local message=$1

  local opts=""

  if [[ ${2:-} != "--init" ]]; then
    opts="--edit-last"
  fi

  local starting_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state
  git pull
  state=$(cat state.json)

  # we only want to display our ancestors, those behind us in the queue are
  # irrelevant
  local ancestors=$(
    echo "$state" |
      jq --raw-output \
         --arg name "${MERGE_BRANCH:-}" \
         '.mergeBranches[] | select(.name == $name) | .ancestors[]'
  )

  local table_output="### Your place in the queue:

Position | Status | PR | CI Branch |
:---: | :---: | :--- | :--- |
"

  local rows_output=""
  local position=1
  local branch
  while read -r branch; do
    local this_status=$(
      echo $state |
      jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .status'
    )
    local this_pr_number=$(
      echo $state |
      jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .pr_number'
    )
    local this_title=$(
      echo $state |
      jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .title'
    )
    local this_merge_branch=$(
      echo $state |
      jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .name'
    )

    # the ancestor might have been removed from the queue by now
    if [ -z "$this_merge_branch" ]; then
      continue
    fi

    rows_output+="$position |"
    position=$(($position + 1))

    if [[ "$this_status" == "failed" ]]; then
        rows_output+="🔴 |"
    elif [[ "$this_status" == "succeeded" ]]; then
        rows_output+="🟢 |"
    else
        rows_output+="🟡 |"
    fi

    rows_output+="[$this_title](https://github.com/$PROJECT_REPO/pull/$this_pr_number) |"

    rows_output+="[$this_merge_branch](https://app.circleci.com/pipelines/github/$PROJECT_REPO?branch=$this_merge_branch) |"

    rows_output+="
"
  done <<< "$ancestors"


  # add ourselves
  if [[ -n "$rows_output" ]]; then
     rows_output+="$position | 🟡 | 🫵 | [$MERGE_BRANCH](https://app.circleci.com/pipelines/github/$PROJECT_REPO?branch=$MERGE_BRANCH)

"
  fi

  local output=""
  if [[ "$ATTEMPT" != "1" ]]; then
    output+="_Attempt $ATTEMPT_

"
  fi

  if [ -n "$rows_output" ]; then
    output+="$table_output"
    output+="$rows_output"
  fi

  output+="$message
"
  gh pr comment $PR_NUMBER --repo $PROJECT_REPO --body "$output" $opts

  cd $starting_dir
}

# With a sad update merging isn't going to happen here, so no need for the merge
# queue output
sad_update () {
  local message=$1

  gh pr comment $PR_NUMBER --repo $PROJECT_REPO --body "$message" --edit-last
}
