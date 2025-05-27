#!/usr/bin/env bash

. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/merge.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/cleanup.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/manage-queue-state.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/merge-queue-lock.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/mergeability.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/output.sh

merge
# main () {
#   # try 3 times
#   for i in {1..3}; do
#     merge
#   done
# }
