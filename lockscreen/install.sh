#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ${EUID} -eq 0 ]]; then
    scope="--system"
else
    scope="--user"
fi

exec "${SCRIPT_DIR}/../install.sh" "${scope}" --component lockscreen "$@"
