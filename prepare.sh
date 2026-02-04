#!/bin/bash

# version of charts, must be semver and doesn't have to match Paragon appVersion
version="2026.02.03"

# defaults
provider="aws"
tag=""

# parse flags
usage() {
  echo "Usage: ./prepare.sh [-p <provider>] [-t <tag>]"
  echo ""
  echo "Options:"
  echo "  -p <provider>  aws|azure|gcp|k8s (default: aws)"
  echo "  -t <tag>       Git tag to fetch"
  echo "  -h             Show this help"
  exit "${1:-0}"
}

while getopts "t:p:h" opt; do
  case $opt in
    t) tag="$OPTARG" ;;
    p) provider="$OPTARG" ;;
    h) usage ;;
    \?) usage 1 ;;
  esac
done

# if provider is not provided, use aws
if [[ -z "$provider" ]]; then
  provider="aws"
else
  # verify provider is one of the allowed values
  if [[ ! "$provider" =~ ^(aws|azure|gcp|k8s)$ ]]; then
    echo "Error: Invalid provider '$provider'. Must be one of: aws, azure, gcp, k8s"
    exit 1
  fi
fi

# Fetch the tags from the remote repository
git fetch --tags --quiet

# If tag is not provided, use latest tag
if [[ -z "$tag" ]]; then
  echo "No tag provided, attempting to use latest tag"
  tag=$(git tag --sort=-v:refname | head -n 1)

  if [[ -z "$tag" ]]; then
    echo "Error: No tags found in this repository"
    exit 1
  fi

  echo "Using latest tag: $tag"
fi

# validate tag exists
if ! git show-ref --tags --quiet "refs/tags/$tag"; then
  echo "Error: Tag '$tag' not found"
  exit 1
fi

# Fetch services inputs from git tag
# Create a temp directory
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Get the repository root directory (where .git folder is)
# This ensures git archive works correctly even when script is run from a subdirectory
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$repo_root" ]]; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Extract files from the git tag to temp directory
# Run git archive from the repo root to ensure we get all files
if ! (cd "$repo_root" && git archive --format=tar "$tag") | tar -xf - -C "$temp_dir"; then
  echo "Error: Failed to extract files from git tag '$tag'"
  exit 1
fi

# Path to the input JSON file from the tag
input_json="$temp_dir/charts/files/service-inputs.json"

if [[ ! -f "$input_json" ]]; then
  echo "Error: Input JSON file not found in temp directory: $input_json"
  exit 1
fi

# allow calling from other directories
script_dir=$(dirname "$(realpath "$0")")

# Execute update-charts.mjs with the input JSON
# Use script_dir to ensure the path is correct regardless of where the script is run from
node "$script_dir/scripts/update-charts.mjs" "$input_json"
workspaces=$script_dir/$provider/workspaces

# aws, azure and gcp use terraform, k8s uses helm from dist
if [[ "$provider" == "k8s" ]]; then
    destination=$script_dir/dist
else
    destination=$script_dir/$provider/workspaces/paragon/charts
fi

echo "ℹ️ preparing: $provider"

# create charts folder as needed
mkdir -p $destination

# copy charts to provider destination
if [[ "$provider" == "k8s" ]]; then
    # For k8s provider, copy everything including example.yaml and bootstrap
    rsync -aqv --delete $script_dir/charts/ $destination
else
    # For terraform providers (aws, azure, gcp), exclude example.yaml and bootstrap
    rsync -aqv --delete --exclude='example.yaml' --exclude='values.placeholder.yaml' --exclude='bootstrap/' $script_dir/charts/ $destination
fi

# update version using hash of chart folders
charts=($destination/*/)
for chart in "${charts[@]}"
do
    # sha256 hash of all files in the chart folder with paths sorted then stripped for consistency across providers
    hash=$(find $chart -type f | sort | xargs shasum -a 256 -b | awk '{print $1}' | shasum -a 256 | awk '{print $1}' | cut -c1-8)
    find $chart -type f -exec sed -i '' -e "s/__PARAGON_VERSION__/$version-$hash/g" {} +
    echo "$(basename "$chart"): $hash"
done

# copy main.tf.example files as needed
if [[ "$provider" != "k8s" ]]; then
    mkdir -p $workspaces/paragon/.secure

    if [[ ! -f "$workspaces/infra/main.tf" ]]; then
        cp "$workspaces/infra/main.tf.example" "$workspaces/infra/main.tf"
    fi
    if [[ ! -f "$workspaces/paragon/main.tf" ]]; then
        cp "$workspaces/paragon/main.tf.example" "$workspaces/paragon/main.tf"
    fi

    create_values_yaml() {
        local file="$1"
        local source="$script_dir/charts/values.placeholder.yaml"

        if [[ ! -f "$file" ]]; then
            cp "$source" "$file"
        fi
    }

    generate_tfvars() {
        local vars_file="$1"
        local out_file="$2"

        if [[ -f "$out_file" ]]; then
            return
        fi

        node "$script_dir/scripts/generate-tfvars.mjs" "$vars_file" "$out_file"
    }

    generate_tfvars "$workspaces/infra/variables.tf" "$workspaces/infra/vars.auto.tfvars"
    generate_tfvars "$workspaces/paragon/variables.tf" "$workspaces/paragon/vars.auto.tfvars"
    create_values_yaml "$workspaces/paragon/.secure/values.yaml"
fi

echo "✅ preparations complete!"
