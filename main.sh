#! /bin/bash

## Required Bootstrap VARIABLES
export UPDATE_TO_KUBERNETES_VERSION="${UPDATE_TO_KUBERNETES_VERSION:-1.17.3}"
export TEMP_FOLDER="${TEMP_FOLDER:-.tmp/}"
export CLUSTERS_FILE_NAME="${CLUSTERS_FILE_NAME:-clusterUpgradeCandidatesSummary.json}"
export ERR_LOG_FILE_NAME="${ERR_LOG_FILE_NAME:-err.log}"

## Optional Variable - takes an array example: ("clusterRG_1:clusterName_1" "clusterRG_2:clusterName_2") 
## and will use array to filter/opt-out specific clusters from upgrade

# Load/Import Scripts
## Load helper functions
source ./000-helperFunctions.sh
## Load Cluster Level Operation functions
source ./020-clusterOperations.sh

function main() {
    helperCheckScriptRequirements
    helperClearTempFiles
    createClusterUpgradeCandidatesJSON
    checkAndRollingUpgradeAllClustersAndNodePools
}