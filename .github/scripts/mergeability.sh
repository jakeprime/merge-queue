#!/usr/bin/env bash

ensure_pr_still_mergeable () {
  # Ensure PR hasn't been updated since we joined the queue
  local current_sha=$(gh pr view $PR_NUMBER --repo $PROJECT_REPO --json headRefOid --jq '.headRefOid')
  if [[ "$PR_SHA" != "$current_sha" ]]; then
    # sad_ending "🙃 The PR has been updated since the merge started, halting process"
    sad_update "🙃 The PR has been updated since the merge started, halting process"
    # We've failed, but we're not exiting so we can retry
    cleanup
    RETRY=1
    return 0
  fi

  # Check we're still in the queue. If we're not it means an ancestor has failed
  # so we would too.
  local starting_dir=$(pwd)

  cd $GITHUB_WORKSPACE/merge-queue-state
  git pull

  branch=$(
    cat state.json |
      jq --arg name "$MERGE_BRANCH" \
         '.mergeBranches[] | select(.name == $name)'
        )

  cd $starting_dir

  if [ -z "$branch" ]; then
    sad_update "👎 Bad luck, an earlier PR in the queue has failed, trying again..."
    cleanup
    # We've failed, but we're not exiting so we can retry
    RETRY=1
  fi
}
