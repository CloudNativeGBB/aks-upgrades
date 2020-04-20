#! /bin/bash

## Required Bootstrap VARIABLES
export UPDATE_TO_KUBERNETES_VERSION="1.16.7"
export TEMP_FOLDER=".tmp/"
export CLUSTERS_FILE_NAME="clusterUpgradeCandidatesSummary.json"
export ERR_LOG_FILE_NAME="err.log"

# Load/Import Scripts
## Load helper functions
source ./000-helperFunctions.sh
## Load Cluster Level Operation functions
source ./020-clusterOperations.sh

function main() {
    # Check prerequisites
    helperCheckScriptRequirements
    helperClearTempFiles

    # Find Cluster Upgrade Candidates
    createClusterUpgradeCandidatesJSON

    # Check if Control Plane Needs Upgrade First
    checkClusterControlPlanes

    # Upgrade All NodePools in Eligible Clusters
    upgradeAllClustersAndNodePools
}