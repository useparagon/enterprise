#! /usr/bin/env bash
TAG="$1"
PLATFORM_ENV="$2" # for later use

# This script commits all changes and pushes them as a tagged commit
# without pushing any changes to the current branch.

function die() { echo >&2 "$@"; exit 1; }

[[ $TAG ]] || die "Missing version tag"
[[ $TAG =~ ^[[:alnum:]_.-]+$ ]] || die "Version tag contains invalid characters: '$TAG'"

git config --global user.name 'Automated Helm Chart Updates'
git config --global user.email 'paragonbot@useparagon.com'

git add .
git commit -m "Automated update $TAG"

git tag -f "$TAG"
git push -f origin "$TAG"
