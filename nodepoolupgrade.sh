#!/bin/bash

# The following assumes the system node pool is tainted with CriticalAddonsOnly and no scheduling.
# eg. kubectl taint node aks-nodepool1-38406395-vmss000000 CriticalAddonsOnly=:PreferNoSchedule

# High-Level Steps
# 1. Find Existing Nodes
# 2. Create New Nodepool
# 3. Taint Existing Nodepool
# 4. Cordon/Drain Existing Nodepool
# 5. Delete Current Nodepool

RG=khaks-rg
NAME=khaks20200415
CURRENT_NODEPOOL=nodepool2
NEW_NODEPOOL=nodepool3

# Find current NodePool nodes and create file
# while NODES= read -r NODE
# do
#     echo "$NODE"
# done < <(kubectl get nodes | awk 'NR>1 {print $1}')
kubectl get nodes | grep -i $CURRENT_NODEPOOL | awk '{print $1}' > nodes.txt

# Create new NodePool for workloads to move too
echo "Creating new NodePool"
az aks nodepool add -g $RG --cluster-name $NAME -n $NEW_NODEPOOL -c 1
echo "done"

# Taint current Nodepool so nothing new gets scheduled
echo "Tainting current NodePool"
while NODES= read -r NODE
do
    echo "*****Tainting ${NODE}"
    kubectl taint node $NODE GettingUpgraded=:NoSchedule
    echo "*****done"
done < nodes.txt
echo "done"

# Drain workloads from current NodePool
echo "Draining current NodePool"
while NODES= read -r NODE
do
    echo "*****Draining ${NODE}"
    kubectl drain $NODE --ignore-daemonsets --delete-local-data
    sleep 60
    echo "*****done"
done < nodes.txt
echo "done"

# Delete current NodePool
echo "Deleting current NodePool"
az aks nodepool delete -g $RG --cluster-name $NAME -n $CURRENT_NODEPOOL
echo "done"

echo "Completed upgrade via NodePools successfully."
