#! /bin/bash

## Node Level Operations
# Taint Node so nothing gets scheduled onto it
function taintNode() {
    local __nodeName=$1
    
    echo "Tainting Node $__nodeName"

    
    echo "*****Tainting $__nodeName"
    kubectl taint node $__nodeName GettingUpgraded=:NoSchedule
    echo "*****done - Tainting"
    
}

function drainNode() {
    local __nodeName=$1

    # Drain workloads from node $__nodeName
    echo "*****Draining $__nodeName"
    
    kubectl drain $__nodeName \
        --ignore-daemonsets \
        --delete-local-data

    sleep 60
    
    echo "*****done - Draining"
}
