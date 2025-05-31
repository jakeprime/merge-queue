#!/usr/bin/env bash

# Things have not gone to plan, clean up and exit
sad_ending () {
  local message=$1

  sad_update "$message"

  lock_merge_queue

  # --safely, so we don't exit early if the merge branch doesn't exist
  remove_branch_from_queue --safely
  remove_descendants_from_queue

  cd $GITHUB_WORKSPACE/project

  unlock_merge_queue --force

  exit 0
}
