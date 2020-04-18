#! /bin/bash

### Cluster functions
function createClusterUpgradeCandidatesJSON(){
    local __fileName="clusterUpgradeCandidates.tsv"

    echo "Generating list of AKS CLusters to upgrade..."

    local $__tsv=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION']].{name: name, resourceGroup: resourceGroup, kubernetesVersion: kubernetesVersion}}" -o tsv)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of cluster upgrade candidates"
        echo $$__tsv | tee .tmp/$__fileName
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

function checkControlPlanes() {
    local __fileName="clusterUpgradeCandidates.json"
}

function checkControlPlane() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4

    controlPlaneNeedsUpgrade $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion
}

function controlPlaneNeedsUpgrade() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4

    if [ $(helperCheckSemVer $__clusterK8sVersion) -lt $(helperCheckSemVer $__targetK8sVersion) ]
    then
        echo "Control Plane Upgrade needed."
        echo "Control Plane version equal to: $__clusterK8sVersion"
        echo "Target K8s $__targetK8sVersion"
        
        upgradeControlPlane $__RG $__clusterName $__targetK8sVersion
        
        if [ $? -eq 0]
        then
            return 0
        else
            echo "Control Plane Upgrade Failed." > err.log
            return 1
        fi
    else 
        echo "Control Plane Upgrade not needed."
        echo "Control Plane version equal to: $__clusterK8sVersion."
        echo "Target K8s $__targetK8sVersion"

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
    if [$? -eq 0]
    then
        echo "Succeeded: Control Plane Upgrade Complete now at version $__K8SVersion"
        echo "Finished at: $(date)"
        return 0
    else 
        echo "Failed: Control Plane Upgrade to version $__K8SVersion"
        return 1
    fi
    
}