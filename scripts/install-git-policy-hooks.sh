#!/usr/bin/env bash
set -euo pipefail

git config user.name "gitbyul"
git config user.email "gitbyul@gmail.com"
git config core.hooksPath .githooks

chmod +x scripts/validate-git-policy.sh
chmod +x .githooks/commit-msg
chmod +x .githooks/pre-push

echo "Git policy hooks installed."
echo "Configured local identity: gitbyul <gitbyul@gmail.com>"
