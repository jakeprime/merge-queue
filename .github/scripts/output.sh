#!/usr/bin/env bash

# Message supplied and the state of the queue
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
      jq -r --arg name "${MERGE_BRANCH:-}" \
         '.mergeBranches[] | select(.name == $name) | .ancestors[]'
  )

  local table_output="### PRs ahead of us

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

  local output="$message
"
  if [ -n "$rows_output" ]; then
    output+="$table_output"
    output+="$rows_output"
  fi

  gh pr comment $PR_NUMBER --repo $PROJECT_REPO --body "$output" $opts

  cd $starting_dir
}

# This would be a terminal state, so just the message not the queue state
sad_update () {
  local message=$1

  gh pr comment $PR_NUMBER --repo $PROJECT_REPO --body "$message" --edit-last
}
