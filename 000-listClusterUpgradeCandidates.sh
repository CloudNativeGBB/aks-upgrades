#! /bin/bash

## VARIABLES FILE
export AZURE_SUBSCRIPTION_ID=
export UPDATE_TO_KUBERNETES_VERSION="1.15.19"
export K8S_CONTROL_PLANE_UPGRADE_ONLY=false
export IN_PLACE_NODE_UPDATE=false

## Load Helpers
source ./helperFunctions.sh

