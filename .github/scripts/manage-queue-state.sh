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
    # can't call sad_ending from here as that calls this and we could be stuck
    # in a loop
    sad_update "💣 Error - failed updating the merge queue, aborting"
    unlock_merge_queue --force
    exit 1
  fi

  echo "$state" > state.json

  unlock_merge_queue

  cd $GITHUB_WORKSPACE/project
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
    # can't call sad_ending from here as that calls this and we could be stuck
    # in a loop
    sad_update "💣 Error - failed updating the merge queue, aborting"
    unlock_merge_queue --force
    exit 1
  fi

  echo "$state" > state.json

  unlock_merge_queue

  cd $start_dir
}
