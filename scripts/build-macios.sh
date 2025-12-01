#!/bin/bash -eux

set -o pipefail
IFS=$'\n\t'

# Navigate to the parent directory of the scripts folder
PARENT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
cd "$PARENT_DIR"

# Clone macios repository if it doesn't exist in parent directory
if [ ! -d "macios" ]; then
	git clone https://github.com/dotnet/macios.git
fi

cd macios
git checkout feature/coreclr-r2r

if [[ "${1:-}" != "--skip-clean" ]]; then
	git clean -xfd
	RUNTIME_PATH=../runtime
	RUNTIME_PATH=$(cd "$RUNTIME_PATH" && pwd)
	./configure --disable-all-platforms --enable-ios --disable-simulator --custom-dotnet="$RUNTIME_PATH"
	make reset
fi

make all -j8
make install -j8
