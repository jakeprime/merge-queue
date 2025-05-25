#!/usr/bin/env bash

set -euo pipefail

. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/cleanup.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/manage-queue-state.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/merge-queue-lock.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/mergeability.sh
. $GITHUB_WORKSPACE/merge-queue-repo/.github/scripts/output.sh
