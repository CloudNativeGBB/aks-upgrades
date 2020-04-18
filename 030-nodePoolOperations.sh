#! /bin/bash

### Node Pool functions
function createNodePoolUpgradeCandidatesJSON(){
    echo "Generating list of AKS Node Pools to upgrade..."

    local __list=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION']].{name: name, resourceGroup: resourceGroup, kubernetesVersion: kubernetesVersion, agentPoolProfiles: agentPoolProfiles[].{name: name, orchestratorVersion: orchestratorVersion}}" -o json)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of Node Pool upgrade candidates"
        echo $__list | tee .tmp/nodePoolUpgradeCandidates.json
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
    local __nodePoolName=$1

    # Find current NodePool nodes and create file
    echo $(kubectl get nodes | grep -i $__nodePoolName | awk '{print $1}') | tee listNodesinNodePool-$__nodePoolName.txt
    return 0
}

# Taint Node Pool
function tainitNodePool() {
    while NODES= read -r NODE
    do
        taintNode $__nodeName
    done < nodes.txt

    echo "done - Tainting current NodePool"
}

function drainNodePools() {

}

function drainNodePool() {
    local __nodePoolName=$1

    echo "Draining current NodePool"

    while NODES= read -r NODE
    do
      drainNode $__nodeName  
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
