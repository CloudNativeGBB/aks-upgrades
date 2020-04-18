#! /bin/bash

## Required Bootstrap VARIABLES
export AZURE_SUBSCRIPTION_ID=
export UPDATE_TO_KUBERNETES_VERSION="1.15.19"
export K8S_CONTROL_PLANE_UPGRADE_ONLY=false
export IN_PLACE_NODE_UPDATE=false

# Load/Import Scripts
## Load helper functions
source ./001-helperFunctions.sh
## Load Azure CLI pre-flight Operation functions
source ./010-azCLIOperations.sh
## Load Cluster Level Operation functions
source ./002-clusterOperations
## Load nodePool Level Operation functions
source ./003-nodePoolOperations
## Load node Level Operation functions
source ./004-nodeOperations

# Check prerequisites
helperCheckScriptRequirements

# Set Azure CLI to right Subscription
setSubscription $AZURE_SUBSCRIPTION_ID

# Find Cluster Upgrade Candidates
createClusterUpgradeCandidatesJSON

# 

