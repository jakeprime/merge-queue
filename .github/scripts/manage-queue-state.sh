#!/usr/bin/env bash

remove_branch_from_queue () {
  start_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state

  lock_merge_queue

  local state=$(
    cat state.json |
      jq --arg name "$MERGE_BRANCH" \
         '.mergeBranches |= map(select(.name != $name))'
        )

  if [ -z "$state" ]; then
    echo "error editing state"
    exit 1
  fi

  echo "$state" > state.json

  unlock_merge_queue

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
    echo "error editing state"
    exit 1
  fi

  echo "$state" > state.json

  unlock_merge_queue

  cd $start_dir
}
