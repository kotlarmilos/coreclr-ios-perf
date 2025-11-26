#!/bin/bash -eux

set -o pipefail
IFS=$'\n\t'

# Navigate to the parent directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Clone runtime repository if it doesn't exist in parent directory
if [ ! -d "runtime" ]; then
	git clone https://github.com/dotnet/runtime.git
fi

cd runtime
./build.sh --restore --build --pack --configuration Release /p:TargetRid=ios-arm64 --arch arm64 --os ios /p:DotNetBuildAllRuntimePacks=true
