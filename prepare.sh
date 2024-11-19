#!/bin/bash

# version of charts, must be semver and doesn't have to match Paragon appVersion
version="2024.0.0"

provider=${1:-aws}
destination=$provider/workspaces/paragon/charts
echo "ℹ️ preparing: $provider"

# create .secure and charts folders as needed
mkdir -p $provider/workspaces/paragon/.secure
mkdir -p $destination

# copy charts to provider terraform
rsync -aqv --delete charts/ $destination

# update version using hash of chart folders
charts=($destination/*/)
for chart in "${charts[@]}"
do
    hash=$(find $chart -type f -exec shasum -a 256 {} + | sort | shasum -a 256 | awk '{print $1}' | cut -c1-8)
    echo "$(basename "$chart"): $hash"

    find $chart -type f -exec sed -i '' -e "s/__PARAGON_VERSION__/$version-$hash/g" {} +
done

# copy main.tf.example files as needed
if [[ ! -f "$provider/workspaces/infra/main.tf" ]]; then
    cp "$provider/workspaces/infra/main.tf.example" "$provider/workspaces/infra/main.tf"
fi
if [[ ! -f "$provider/workspaces/paragon/main.tf" ]]; then
    cp "$provider/workspaces/paragon/main.tf.example" "$provider/workspaces/paragon/main.tf"
fi

echo "✅ preparations complete!"
