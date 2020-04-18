#!/bin/bash

# The following assumes the system node pool is tainted with CriticalAddonsOnly and no scheduling, 
# and a second user nodepool exists.
# kubectl taint node aks-nodepool1-38406395-vmss000000 CriticalAddonsOnly=:PreferNoSchedule
# az aks nodepool add -g $RG --cluster-name $NAME -n nodepool2 -c 1 --mode user

# High-Level Steps
# 1. Check Cluster Exists
# 2. Check Current K8s Version
# 3. Find Existing Nodes
# 4. Create New Nodepool
# 5. Taint Existing Nodepool
# 6. Cordon/Drain Existing Nodepool
# 7. Delete Current Nodepool

export KUBERNETES_VERSION=1.16.0
export RG=rg
export NAME=aks
export CURRENT_NODEPOOL=nodepool2
export NEW_NODEPOOL=nodepool3

echo "Assign & Dump Parameters"
KUBERNETES_VERSION=$1
RG=$2
NAME=$3
CURRENT_NODEPOOL=$4
NEW_NODEPOOL=$5
echo "KUBERNETES_VERSION: $KUBERNETES_VERSION"
echo "RG: $RG"
echo "NAME: $NAME"
echo "CURRENT_NODEPOOL: $CURRENT_NODEPOOL"
echo "NEW_NODEPOOL: $NEW_NODEPOOL"
echo "done"

# Function for comparing versions.
function version() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4) }'
}

function getNodePoolDetail() {
    jq ".$1" nodepool.json
}

if [ "$(az aks show -g $RG -n $NAME -o tsv --query 'name')" = "$NAME" ]
then
    echo "Cluster Found"

    cluster_version=$(az aks show -g $RG -n $NAME -o tsv --query 'kubernetesVersion')
    echo "Cluster Version: $cluster_version"
    if [ $(version $cluster_version) -lt $(version $KUBERNETES_VERSION) ]
    then
        echo "Control Plane needs Updating"
        az aks upgrade -g $RG -n $NAME -k $KUBERNETES_VERSION --control-plane-only -y
        echo "done"
    fi

    # Find current NodePool nodes and create file
    kubectl get nodes | grep -i $CURRENT_NODEPOOL | awk '{print $1}' > nodes.txt

    # Check if file is empty
    if [ -s nodes.txt ]
    then
        echo "NodePool Found"

        # Create NodePool File with Details
        az aks nodepool show -g $RG --cluster-name $NAME -n $CURRENT_NODEPOOL > nodepool.json

        # Get NodePool value(s) from json file
        current_nodepool_count=$(getNodePoolDetail 'count')
        echo "Current NodePool Count: $current_nodepool_count"
        current_nodepool_vmsize=$(getNodePoolDetail 'vmSize')
        echo "Current NodePool VM Size: $current_nodepool_vmsize"
        
        # Create new NodePool for workloads to move too
        echo "Creating new NodePool"
        az aks nodepool add -g $RG --cluster-name $NAME -n $NEW_NODEPOOL -c $current_nodepool_count -s current_nodepool_vmsize
        echo "done - Creating new NodePool"

        # Taint current Nodepool so nothing new gets scheduled
        echo "Tainting current NodePool"
        while NODES= read -r NODE
        do
            echo "*****Tainting ${NODE}"
            kubectl taint node $NODE GettingUpgraded=:NoSchedule
            echo "*****done - Tainting"
        done < nodes.txt
        echo "done - Tainting current NodePool"

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

        # Delete current NodePool
        echo "Deleting current NodePool"
        az aks nodepool delete -g $RG --cluster-name $NAME -n $CURRENT_NODEPOOL
        echo "done - Deleting current NodePool"

        echo "NodePool Upgrade Successful"
    else
        echo "NodePool Not Found"
    fi
else
    echo "Cluster Not Found"
fi

echo "Script Completed"
