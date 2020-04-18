#! /bin/bash

## VARIABLES FILE
export AZURE_SUBSCRIPTION_ID=
export UPDATE_TO_KUBERNETES_VERSION="1.15.19"
export K8S_CONTROL_PLANE_UPGRADE_ONLY=false
export IN_PLACE_NODE_UPDATE=false

## Load Helpers
source ./helperFunctions.sh

function checkScriptRequirements(){
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

function setSubscription(){
    echo "Setting target AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"

    az account set --subscription $1

    if [ $? -eq 0 ]
    then
        echo "$(date)   Succeeded to set AZURE_SUBSCRIPTION_ID to: $AZURE_SUBSCRIPTION_ID"
        
    else
        echo "$(date)   Failed to set AZURE_SUBSCRIPTION_ID to: $AZURE_SUBSCRIPTION_ID" >err.log
        return 1
    fi
}

### Cluster functions
function createClusterUpgradeCandidatesJSON(){
    echo "Generating list of AKS CLusters to upgrade..."

    local __list=$(az aks list --query "[?kubernetesVersion < '$UPDATE_TO_KUBERNETES_VERSION'].{name: name, resourceGroup: resourceGroup, kubernetesVersion: kubernetesVersion, agentPoolProfiles: agentPoolProfiles[].{name: name, orchestratorVersion: orchestratorVersion}}" -o json)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of cluster upgrade candidates"
        echo $__list | tee clusterUpgradeCandidates.json
    else
        echo "Failed to create list of cluster upgrade candidates" >err.log 
        return 1
    fi
}

function checkClusterExists() {
    local __RG=$1
    local __clusterName=$2
    
    if [ "$(az aks show -g $__RG -n $__clusterName -o tsv --query 'name')" = "$__clusterName" ]
    then
        echo "Cluster Found"

        cluster_version=$(az aks show -g $RG -n $NAME -o tsv --query 'kubernetesVersion')
        return 0
    else
        echo "Cluster Not Found"
        return 1
    fi
}

function controlPlaneNeedsUpgrade() {
    local __clusterK8sVersion=$1
    local __targetK8sVersion=$2

    if [ $(helperCheckSemVer $__clusterK8sVersion) -lt $(helperCheckSemVer $__targetK8sVersion) ]
    then
        echo "Upgrade needed."
        echo "Cluster K8s ver $__clusterK8sVersion"
        echo "Target K8s $__targetK8sVersion"
        return 0
    else 
        echo "Upgrade not needed. Control Plane up to date $__clusterK8sVersion."
        return 1
    fi
}

function upgradeControlPlane() {
    local __RG=$1
    local __clusterName=$2
    local __K8SVersion=$3

    echo "Upgrading Control Plane..."
    echo "Started at: $(date)"
    
    az aks upgrade \
        -g $__RG \
        -n $__clusterName \
        -k $__K8SVersion \
        --control-plane-only \
        -y
        
    echo "Finished at: $(date)"
    echo "done"
}

### Node Pool functions
function createNodePoolUpgradeCandidatesJSON(){
    echo "Generating list of AKS Node Pools to upgrade..."

    local __list=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION']].{name: name, resourceGroup: resourceGroup, kubernetesVersion: kubernetesVersion, agentPoolProfiles: agentPoolProfiles[].{name: name, orchestratorVersion: orchestratorVersion}}" -o json)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of Node Pool upgrade candidates"
        echo $__list | tee nodePoolUpgradeCandidates.json
    else
        echo "Failed to create list of Node Pool upgrade candidates" >err.log 
        return 1
    fi
}

function checkNodePoolExists() {

}

function createNewNodePool() {
    local __RG=$1
    local __clusterName=$2
    local __nodePoolName=$3
    local __nodePoolCount=$4
    local __nodePoolVMSize=$5

    # Create new NodePool for workloads to move too
    echo "Creating new NodePool"
    
    az aks nodepool add \
        -g $__RG --cluster-name $__clusterName \
        -n $__nodePoolName \
        -c $__nodePoolCount \
        -s $__nodePoolVMSize

    echo "done - Creating new NodePool"
}

function listNodesInNodePool() {
    local __poolName=$1

    # Find current NodePool nodes and create file
    echo $(kubectl get nodes | grep -i $__poolName | awk '{print $1}') | tee listNodesinNodePool-$__poolName.txt
    return 0
}

# Taint Nodepool so nothing gets scheduled onto it
function taintNodePool() {
    local __nodePoolName=$1
    
    echo "Tainting NodePool $__nodePoolName"

    while NODES= read -r NODE
    do
        echo "*****Tainting ${NODE}"
        kubectl taint node $NODE GettingUpgraded=:NoSchedule
        echo "*****done - Tainting"
    done < nodes.txt

    echo "done - Tainting current NodePool"
}

function drainNodePool() {
    # Drain workloads from current NodePool
    echo "Draining current NodePool"
    while NODES= read -r NODE
    do
        echo "*****Draining ${NODE}"
        kubectl drain $NODE --ignore-daemonsets --delete-local-data
        sleep 60
        echo "*****done - Draining"
    done < nodes.txt
    echo "done - Draining current NodePool"
}

function deleteNodePool() {
    local __RG=$1
    local __clusterName=$2
    local __nodePoolName=$3

    # Delete current NodePool
    echo "Deleting current NodePool"
    
    az aks nodepool delete \
        -g $RG \
        --cluster-name $__clusterName \
        -n $__nodePoolName

    if [ $? -eq 0 ]
    then
        echo "Success: Deleted Node Pool: $__nodePoolName"
        return 0
    else
        echo "Failure: Unable to delete Node Pool: $__nodePoolName" > err.log
    fi
}