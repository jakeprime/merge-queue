#!/usr/bin/env bash

# lock format is
#
#    {
#      "id": $GITHUB_RUN_ID,
#      "count": 1
#    }
#
# We'll increment and decrement the lock count whenever locking and unlocking
# so that we can safely lock and unlock around any state management without
# having to check if we already have the lock. When the lock count is at 0
# we can properly release the lock.

lock_merge_queue () {
  local start_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state

  # Check if we already have the lock. We don't need to pull as if we do have it
  # then no one else could have written to the state since we last pulled it
  if [[ -f "lock" && "$(jq -r '.id' lock)" == "$GITHUB_RUN_ID" ]]; then
    # increment counter
    local count=$(($(jq '.count' lock) + 1))
    jq --argjson count $count '.count = $count' lock > tmp && mv tmp lock

    cd $start_dir
    return 0
  fi

  # We need to create it
  for i in {1..12}; do
    git fetch origin $PROJECT_REPO
    git reset --hard origin/$PROJECT_REPO
    git pull

    if [[ -f "lock" ]]; then
      echo "State is locked"
    else
      echo "{\"id\": \"$GITHUB_RUN_ID\", \"count\": 1}" > lock
      git add lock
      git commit -m "Locking merge queue state"

      # this will fail if another runner has pushed a lock before us
      if git push; then
        cd $start_dir
        return 0
      else
        # undo the locking and wait to retry
        git fetch origin $PROJECT_REPO && git reset --hard origin/$PROJECT_REPO
      fi
    fi

    sleep 5
  done

  # we've failed to get the lock
  cd $start_dir
  sad_ending "💣 &nbsp; Error - failed to get a lock on the merge queue"
}

unlock_merge_queue () {
  local start_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state

  if [[ ! -f "state.json" ]]; then
    # we don't have a lock
    return 0
  fi

  # decrement counter
  local count=$(($(jq '.count' lock) - 1))

  jq --argjson count $count '.count = $count' lock > tmp && mv tmp lock

  # if the counter is at zero we can release the lock
  # of if --force is set, that means we are in a sad ending situation
  if [[ $count == 0 || "${1:-}" == "--force" ]]; then
    rm lock
    git add lock state.json
    git commit -m "Releasing lock"
    git push
  fi

  cd $start_dir
}
