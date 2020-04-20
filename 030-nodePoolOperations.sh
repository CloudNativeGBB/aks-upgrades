#! /bin/bash

## Load node Level Operation functions
source "./040-nodeOperations.sh"

function upgradeNodePoolsInCluster() {
    local __clusterName=$1
    local __RG=$(cat .tmp/$CLUSTER_FILE_NAME| jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).resourceGroup')

    for __nodePoolName in $(cat .tmp/$CLUSTER_FILE_NAME| jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).agentPoolProfiles[].name')
    do
        upgradeNodePool $__RG $__clusterName $__nodePoolName
    done
}

function upgradeNodePool() {
    local __RG=$1
    local __clusterName=$2
    local __oldNodePoolName=$3
    local __suffix="v${UPDATE_TO_KUBERNETES_VERSION//./}"  
    local __newNodePoolName=$__oldNodePoolName$__suffix
    local __nodePoolCount=$(cat .tmp/$CLUSTER_FILE_NAME | jq -r --arg clusterName "$__clusterName" --arg nodePoolName "$__oldNodePoolName" '.[] | select(.name==$clusterName).agentPoolProfiles[] | select(.name==$nodePoolName).count')
    local __nodePoolVMSize=$(cat .tmp/$CLUSTER_FILE_NAME | jq -r --arg clusterName "$__clusterName" --arg nodePoolName "$__oldNodePoolName" '.[] | select(.name==$clusterName).agentPoolProfiles[] | select(.name==$nodePoolName).vmSize')

    checkNodePoolNameisValid $__RG $__clusterName $__newNodePoolName
    createNewNodePool $__RG $__clusterName $__newNodePoolName $__nodePoolCount $__nodePoolVMSize
    taintNodePool $__oldNodePoolName
}

function checkNodePoolNameIsValid() {
    local __RG=$1
    local __clusterName=$2
    local __nodePoolName=$3
    # Commented out Reason: az aks nodepool will check length of nodePoolName
    # local __nodePoolNameLength=$(expr length $__nodePoolName)
    local __nameLength=$(expr length $__nodePoolName)
    
    echo $__nameLength

    if [ "$__nameLength" -gt 12 ]
    then
        echo "Name $__nodePoolName Length is greater than 12...try again"
    else 
        echo "Name length is fine"
    fi

    az aks nodepool show -g $__RG --cluster-name $__clusterName -n $__nodePoolName -o json

    if [ $? -eq 0 ]
    then
        echo "Node Pool name $__nodePoolName already Exists"
        return 1
    else 
        echo "Node Pool name $__nodePoolName does not Exist"
        return 0
    fi
}

function createListOfNodesInNodePool() {
    local __nodePoolName=$1

    kubectl get nodes | grep -w -i $__nodePoolName | awk '{print $1}' > .tmp/nodepool-$__nodePoolName.txt
    return 0
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

# Taint Node Pool
function taintNodePool() {
    local __nodePoolName=$1
    local __nodesListFile=".tmp/nodepool-"$__nodePoolName".txt"
    local __taintListFile=".tmp/nodepool-"$__nodePoolName"-taint.txt"

    # duplicate Node List to Taint List to track progress
    cp $__nodesListFile $__taintListFile

    for __nodeName in $(cat $__taintListFile)
    do
        taintNode $__nodeName
    done

    echo "done - Tainting current Node Pool '$__nodePoolName'"
    mv $__taintListFile "$__taintListFile".done
}

function untaintNodePool() {
    local __nodePoolName=$1
    local __nodesListFile=".tmp/nodepool-"$__nodePoolName".txt"
    local __untaintListFile=".tmp/nodepool-"$__nodePoolName"-untaint.txt"

    # duplicate Node List to Taint List to track progress
    cp $__nodesListFile $__untaintListFile

    for __nodeName in $(cat $__untaintListFile)
    do
        untaintNode $__nodePoolName
    done

    echo "done - Untainting current Node Pool '$__nodePoolName'"
    mv $__untaintListFile "$__untaintListFile".done
}

function drainNodePool() {
    local __nodePoolName=$1
    local __nodesListFile=".tmp/nodepool-$__nodePoolName.txt"
    local __drainListFile=".tmp/nodepool-$__nodePoolName-drain.txt"
    
    # duplicate Node List to Taint List to track progress
    cp $__nodesListFile $__drainListFile

    for __nodeName in $(cat $__drainListFile)
    do
        drainNode $__nodeName
    done

    echo "done - Draining current Node Pool '$__nodePoolName'"
    mv $__drainListFile "$__drainListFile".done
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