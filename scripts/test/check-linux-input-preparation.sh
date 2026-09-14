#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../.." && pwd)
library_root=${1:?usage: check-linux-input-preparation.sh LIBVIRTUALHID_CANDIDATE BUILD_OUTPUT}
output=${2:?usage: check-linux-input-preparation.sh LIBVIRTUALHID_CANDIDATE BUILD_OUTPUT}
mkdir -p "$output"
"${CXX:-c++}" -std=c++23 -Wall -Wextra -Werror \
    "-I$library_root/src" "-I$library_root/src/include" \
    "$library_root/tests/portable/linux-input.cpp" -o "$output/linux-input-helpers"
"$output/linux-input-helpers"
python3 -m unittest discover -s "$source_root/tests/input" -p 'test_flame_modifier_profile.py' -v
python3 "$source_root/scripts/test/check-flame-modifier-profile.py" > "$output/modifier-profile.json"
printf '%s\n' 'Static input preparation checks passed; Linux backend and hardware are not qualified.'
