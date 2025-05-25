#!/usr/bin/env bash

ensure_pr_still_mergeable () {
  local starting_dir=$(pwd)

  # Ensure PR hasn't been updated since we joined the queue
  local current_sha=$(gh pr view $PR_NUMBER --repo $PROJECT_REPO --json headRefOid --jq '.headRefOid')
  if [[ "$PR_SHA" != "$current_sha" ]]; then
    sad_ending "🙃 The PR has been updated since the merge started, halting process"
  fi

  # Check we're still in the queue. If we're not it means an ancestor has failed
  # so we would too.
  cd $GITHUB_WORKSPACE/merge-queue-state
  git pull

  branch=$(
    cat state.json |
    jq --arg name "$MERGE_BRANCH" \
       '.mergeBranches[] | select(.name == $name)'
  )

  if [ -z "$branch" ]; then
    sad_ending "👎 Bad luck, an earlier PR in the queue has failed, please try again"
  fi

  cd $starting_dir
}
