#! /bin/bash

## VARIABLES FILE
export AZURE_SUBSCRIPTION_ID=
export UPDATE_TO_KUBERNETES_VERSION="1.15.19"
export IN_PLACE_HOST_UPDATE=FALSE


function setSubscription(){
    echo "Setting target AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"

    az account set --subscription $1

    if [ $? -eq 0 ]
    then
        echo "Succeeded to set AZURE_SUBSCRIPTION_ID to: $AZURE_SUBSCRIPTION_ID"
        
    else
        echo "Failed to set AZURE_SUBSCRIPTION_ID to: $AZURE_SUBSCRIPTION_ID" >>err.log
        return 1
    fi
}

function listClusterUpgradeCandidates(){
    echo "Generating list of AKS CLusters to upgrade..."

    local __list=$(az aks list --query "[?kubernetesVersion < '$UPDATE_TO_KUBERNETES_VERSION'].{id: id, resourceGroup: resourceGroup}" -o json)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of cluster upgrade candidates"
        echo $__list | tee listClusterUpgradeCandidates.json
    else
        echo "Failed to create list of cluster upgrade candidates" >err.log 
        return 1
    fi
}

function listNodePoolUpgradeCandidates(){
    echo "Generating list of AKS Node Pools to upgrade..."

    local __list=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION']].{id: id, resourceGroup: resourceGroup}" -o json)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of Node Pool upgrade candidates"
        echo $__list | tee listNodePoolUpgradeCandidates.json
    else
        echo "Failed to create list of Node Pool upgrade candidates" >err.log 
        return 1
    fi
}



