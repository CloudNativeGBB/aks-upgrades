#! /bin/bash

## Required Bootstrap VARIABLES
export UPDATE_TO_KUBERNETES_VERSION="1.17.3"
export TEMP_FOLDER=".tmp/"
export CLUSTERS_FILE_NAME="clusterUpgradeCandidatesSummary.json"
export ERR_LOG_FILE_NAME="err.log"

# Load/Import Scripts
## Load helper functions
source ./000-helperFunctions.sh
## Load Cluster Level Operation functions
source ./020-clusterOperations.sh

function main() {
    helperCheckScriptRequirements
    helperClearTempFiles
    createClusterUpgradeCandidatesJSON
    checkClusterControlPlanes
    upgradeAllClustersAndNodePools
}