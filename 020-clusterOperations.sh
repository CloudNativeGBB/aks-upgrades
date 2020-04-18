#! /bin/bash

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