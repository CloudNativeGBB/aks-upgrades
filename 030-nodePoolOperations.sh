#! /bin/bash

### Node Pool functions
function createNodePoolUpgradeCandidatesJSON(){
    local __fileName="nodePoolUpgradeCandidates.json"

    echo "Generating list of AKS Node Pools to upgrade..."

        local $__json=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION' && osType == 'Linux']].{name: name, resourceGroup: resourceGroup, kubernetesVersion: kubernetesVersion, agentPoolProfiles: agentPoolProfiles[].{name: name, count: count, vmSize: vmSize, orchestratorVersion: orchestratorVersion}}" -o json)


    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of Node Pool upgrade candidates"
        echo $__json | tee .tmp/$__fileName
    else
        echo "Failed to create list of Node Pool upgrade candidates" > err.log 
        return 1
    fi
}

function upgradeNodePools() {
    local __RG=$1
    local __clusterName=$2
    local __oldNodePoolNames=$3
    
    for __oldNodePoolName in __nodePoolNames
    do
        upgradeNodePool $__RG $__clusterName $__oldNodePoolName
    done
}

function upgradeNodePool() {
    local __RG=$1
    local __clusterName=$2
    local __oldNodePoolName=$3
    local __newNodePoolName=$3-$UPDATE_TO_KUBERNETES_VERSION

    checkNodePoolNameExists $__RG $__clusterName $__oldNodePoolName
}

function checkNodePoolNameExists() {
    local __RG=$1
    local __clusterName=$2
    local __nodePoolName=$3
    # Commented out Reason: az aks nodepool will check length of nodePoolName
    # local __nodePoolNameLength=$(expr length $__nodePoolName)
    local __json=$(az aks nodepool show -g $__RG --cluster-name $__clusterName -n $nodePoolName -o json)

    if [ $? -eq 0 ]
    then
        echo "Node Pool name already Exists"
        return 0
    else 
        echo "Node Pool name does not Exist"
        return 1
    fi
}

function createNewNodePool() {
    local __RG=$1
    local __clusterName=$2
    local __newNodePoolName=$3
    local __nodePoolCount=$4
    local __nodePoolVMSize=$5

    # Create new NodePool for workloads to move too
    echo "Creating new NodePool"
    
    az aks nodepool add \
        -g $__RG --cluster-name $__clusterName \
        -n $__newNodePoolName \
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
