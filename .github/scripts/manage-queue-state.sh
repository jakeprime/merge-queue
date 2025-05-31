#!/usr/bin/env bash

# if --safely is passed we won't error if the merge branch doesn't exist
remove_branch_from_queue () {
  local safely="${1:-}"

  start_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state

  lock_merge_queue

  local state=$(
    cat state.json |
      jq --arg name "$MERGE_BRANCH" \
         '.mergeBranches |= map(select(.name != $name))'
        )

  if [ -z "$state" ]; then
    exit 1
  fi

  echo "$state" > state.json

  unlock_merge_queue

  cd $GITHUB_WORKSPACE/project
  # if we're running --safely return if the branch doesn't exist so we don't error
  if [[ "$safely" == "--safely" && ! $(git branch -r | grep "$MERGE_BRANCH") ]]; then
    cd $start_dir
    return 0
  fi
  git push --delete origin $MERGE_BRANCH

  cd $start_dir
}

remove_descendants_from_queue () {
  start_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state

  lock_merge_queue

  local state=$(
    cat state.json |
      jq --arg branch_name "$MERGE_BRANCH" \
         '.mergeBranches |= map(select((.parents | index($branch_name)) | not))'
        )

  if [ -z "$state" ]; then
    exit 1
  fi

  echo "$state" > state.json

  unlock_merge_queue

  cd $start_dir
}
