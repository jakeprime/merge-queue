#!/usr/bin/env bash

. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/all.sh

# try 3 times
# for i in {1..3}; do
#   merge

#   if [[ -z "${SHOULD_RETRY:-}" ]]; then
#     return 0
#   fi
# done

merge
