#! /bin/bash

function helperCheckScriptRequirements(){
    local __requirements=("az" "jq" "kubectl")

    for __req in ${__requirements[@]}; do
        which $__req

        if [ $? -eq 0 ]
        then
            echo "$(date)   SUCCESS Requirement: $__req found."
        else
            echo "$(date)   FAILED Requirement: $__req not found.  Please install '$__req'." > err.log
            retrun 0
        fi
    done
}

# Function for comparing versions.
function helperCheckSemVer() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4) }'
}