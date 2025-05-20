#!/usr/bin/env bash

set -euo pipefail

cd $GITHUB_WORKSPACE/merge-queue-state

rm lock
git add lock
git commit -m "Unlocking merge queue state"
git push
