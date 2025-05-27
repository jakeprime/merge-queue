#!/usr/bin/env bash

. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/merge.sh

. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/cleanup.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/manage-queue-state.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/merge-queue-lock.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/mergeability.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/output.sh

# If we merge successfully or we have a terminal failure we'll have called
# `exit`. Otherwise we should retry, a maximum of twice.
for i in {1..3}; do
  RETRY=0

  merge
done
