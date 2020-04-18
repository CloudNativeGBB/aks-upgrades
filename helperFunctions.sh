#! /bin/bash

# Function for comparing versions.
function helperCheckSemVer() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4) }'
}