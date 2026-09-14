#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:?usage: check-decode-contract.sh PRIVATE_OUTPUT_DIRECTORY}
mkdir -p "$output"
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror \
    "$source_root/tests/video/decode-contract.cpp" -o "$output/decode-contract"
"$output/decode-contract"
