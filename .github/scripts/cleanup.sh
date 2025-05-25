#!/usr/bin/env bash

# Things have not gone to plan, clean up and exit
sad_ending () {
  local message=$1

  sad_update "$message"

  remove_branch_from_queue
  remove_descendants_from_queue

  cd $GITHUB_WORKSPACE/project
  git push --delete origin $MERGE_BRANCH

  unlock_merge_queue --force

  exit 1
}
