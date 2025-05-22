#!/usr/bin/env bash

set -euo pipefail

starting_dir=$(pwd)

cd $GITHUB_WORKSPACE/merge-queue-state

git pull

state="$(cat $GITHUB_WORKSPACE/merge-queue-state/state.json)"

parents="$(
  echo $state |
  jq -r --arg name "$merge_branch" \
    '.mergeBranches[] | select(.name == $name) | .parents | . += [$name] | .[]'
)"

echo "$parents"

output=""

table_output="### Merge queue
"

table_output+="
Position | Status | PR | CI Branch |
:---: | :---: | :--- | :--- |
"

rows_output=""

position=1
while read -r branch; do
  echo "looping"
  if [ -z $branch ]; then
    continue
  fi

  echo "branch exists"

  this_status=$(
    echo $state |
    jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .status'
  )
  this_pr_number="$(
    echo $state |
    jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .pr_number'
  )"
  this_title="$(
    echo $state |
    jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .title'
  )"
  this_merge_branch="$(
    echo $state |
    jq -r --arg name "$branch" '.mergeBranches[] | select(.name == $name) | .name'
  )"

  rows_output+="$position |"
  position=$(($position + 1))

  if [[ "$this_status" == "failed" ]]; then
      rows_output+="🔴 |"
  elif [[ "$this_status" == "succeeded" ]]; then
      rows_output+="🟢 |"
  else
      rows_output+="🟡 |"
  fi

  if [[ "$merge_branch" == "$branch" ]]; then
    rows_output+="🫵 |"
  else
    rows_output+="[$this_title](https://github.com/$PROJECT_REPO/pull/$this_pr_number) |"
  fi

  rows_output+="[$this_merge_branch](https://app.circleci.com/pipelines/github/$PROJECT_REPO?branch=$this_merge_branch) |"

  rows_output+="
"
done <<< "$parents"

if [ -n "$rows_output" ]; then
  output+="$table_output"
  output+="$rows_output"
  output+="
"
  echo "we have rows"
  echo "$rows_output"
  echo "$output#"
else
  echo "apparently there are no rows:"
  echo "$rows_output"
fi

if [ -n "$log_message" ]; then
    output+="$log_message"
fi

echo "posting comment:"
echo "gh pr comment $pr_number --repo $PROJECT_REPO --body \"$output\" --edit-last --create-if-none"
gh pr comment $pr_number --repo $PROJECT_REPO --body "$output" --edit-last --create-if-none

cd $starting_dir
