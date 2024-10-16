#!/bin/bash

# version of charts, must be semver and doesn't have to match Paragon appVersion
version="2024.0.0"

provider=${1:-aws}
destination=$provider/workspaces/paragon/charts
echo "Preparing: $provider"

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
