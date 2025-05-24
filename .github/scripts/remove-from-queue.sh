#!/usr/bin/env bash

remove_branch_from_queue () {
  local branch_name=$1

  get_merge_queue_lock

  if [[ "$locked_state" == "unlocked" ]]; then
    lock_state
  fi

  local state=$(
    cat state.json |
    jq --arg name "$branch_name" \
       '.mergeBranches |= map(select(.name != $name))'
  )

  if [ -z "$state" ]; then
    echo "error editing state"
    exit 1
  fi

  echo "$state" > state.json

  cat state.json

  git add state.json
  git commit -m "Removing $branch_name from queue"
  git push

  release_merge_queue_lock
}

