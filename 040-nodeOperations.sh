#! /bin/bash

## Node Level Operations
# Taint Node so nothing gets scheduled onto it
function taintNode() {
    local __nodeName=$1
    
    echo "Tainting Node '$__nodeName' in Node Pool '$__nodePoolName'"        
    kubectl taint node $__nodeName GettingUpgraded=:NoSchedule
    # remove node name from list to track progress
    sed -e s/$__nodeName//g -i $__taintListFile
    echo "Done: Node '$__nodeName' in Node Pool '$__nodePoolName' Tainted."
}

function untaintNode() {
    local __nodeName=$1

    echo "Untainting Node '$__nodeName' in Node Pool '$__nodePoolName'"
    kubectl taint node $__nodeName GettingUpgraded=:NoSchedule-
    # remove node name from list to track progress
    sed -e s/$__nodeName//g -i $__untaintListFile
    echo "Done: Node '$__nodeName' in Node Pool '$__nodePoolName' Untainted."
}

function drainNode() {
    local __nodeName=$1

    echo "Draining Node '$__nodeName' in Node Pool '$__nodePoolName'"
    kubectl drain $NODE --ignore-daemonsets --delete-local-data
    sleep 60
    # remove node name from list to track progress
    sed -e s/$__nodeName//g -i $__drainListFile
    echo "Done: Node '$__nodeName' in Node Pool '$__nodePoolName' Drained."
}
