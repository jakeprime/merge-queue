#!/usr/bin/env bash

set -euo pipefail

cd $GITHUB_WORKSPACE/merge-queue-state

for i in {1..12}; do
  git fetch origin $PROJECT_REPO
  git reset --hard origin/$PROJECT_REPO
  git pull

  if ls lock; then
    echo "State is locked"
  else
    echo "$GITHUB_RUN_ID" > lock
    git add lock
    git commit -m "Locking merge queue state"

    # this will fail if another runner has pushed a lock before us
    if git push; then
      cat state.json
      exit 0
    else
      # undo the locking and wait to retry
      git fetch origin $PROJECT_REPO && git reset --hard origin/$PROJECT_REPO
    fi
  fi

  sleep 5
done

echo "Failed to get lock on merge state"
exit 1
