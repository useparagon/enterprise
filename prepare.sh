#!/bin/bash

# version of charts, must be semver and doesn't have to match Paragon appVersion
version="2025.6.4"
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
rsync -aqv --delete $script_dir/charts/ $destination

# update version using hash of chart folders
charts=($destination/*/)
for chart in "${charts[@]}"
do
    hash=$(find $chart -type f -exec shasum -a 256 {} + | sort | shasum -a 256 | awk '{print $1}' | cut -c1-8)
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
