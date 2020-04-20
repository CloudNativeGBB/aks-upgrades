#! /bin/bash

## Required Bootstrap VARIABLES
export AZURE_SUBSCRIPTION_ID=
export UPDATE_TO_KUBERNETES_VERSION="1.16.7"
export K8S_CONTROL_PLANE_UPGRADE_ONLY=false
export IN_PLACE_NODE_UPDATE=false
export CLUSTER_FILE_NAME="clusterUpgradeCandidates.json"

# Load/Import Scripts
## Load helper functions
source ./000-helperFunctions.sh
## Load Azure CLI pre-flight Operation functions
source ./010-azCLIOperations.sh
## Load Cluster Level Operation functions
source ./020-clusterOperations.sh

function main() {
    # Check prerequisites
    helperCheckScriptRequirements
    helperClearTempFiles

    # Set Azure CLI to right Subscription
    setSubscription $AZURE_SUBSCRIPTION_ID

    # Find Cluster Upgrade Candidates
    createClusterUpgradeCandidatesJSON

    # Check if Control Plane Needs Upgrade First
    checkClusterControlPlanes

    # Upgrade All NodePools in Eligible Clusters
    upgradeAllClustersAndNodePools
}