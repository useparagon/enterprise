#!/bin/bash

# version of charts, must be semver and doesn't have to match Paragon appVersion
version="2025.10.23"
provider=${1:-aws}

# allow calling from other directories
script_dir=$(dirname "$(realpath "$0")")
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
    rsync -aqv --delete --exclude='example.yaml' --exclude='bootstrap/' $script_dir/charts/ $destination
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
fi

echo "✅ preparations complete!"
