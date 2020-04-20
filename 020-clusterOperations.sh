#! /bin/bash

# Expected variables to be exported by calling script(s):
# $UPDATE_TO_KUBERNETES_VERSION
# $CLUSTER_FILE_NAME

## Load nodePool Level Operation functions
source "./030-nodePoolOperations.sh"

### Cluster functions
function createClusterUpgradeCandidatesJSON(){
    echo "Generating list of AKS CLusters to upgrade..."

    local __candidatesFullDetails=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION' && osType == 'Linux' && mode == 'User']]" -o json)

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of cluster upgrade candidates"
        echo $__candidatesFullDetails > "$TEMP_FOLDER/clusterUpgradeCandidatesFullDetails.json"
        local __candidatesSummaryDetails=$(az aks list --query "[?agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION' && osType == 'Linux']].{name: name, resourceGroup: resourceGroup, kubernetesVersion: kubernetesVersion, agentPoolProfiles: agentPoolProfiles[].{name: name, count: count, vmSize: vmSize, orchestratorVersion: orchestratorVersion}}" -o json)
        echo $__candidatesSummaryDetails > "$TEMP_FOLDER/$CLUSTER_FILE_NAME"
    else
        echo "Failed to create list of cluster upgrade candidates" >> $TEMP_FOLDER$ERR_LOG_FILE_NAME
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

function checkClusterControlPlanes() {
    for __clusterName in $(cat "$TEMP_FOLDER/$CLUSTER_FILE_NAME" | jq -r '.[] | .name')    
    do
        local __RG=$(cat "$TEMP_FOLDER/$CLUSTER_FILE_NAME" | jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).resourceGroup')
        local __clusterK8sVersion=$(cat "$TEMP_FOLDER/$CLUSTER_FILE_NAME" | jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).kubernetesVersion')
        local __targetK8sVersion=$UPDATE_TO_KUBERNETES_VERSION
        
        checkClusterControlPlane $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion
    done
}

function checkClusterControlPlane() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4

    checkClusterControlPlaneNeedsUpgrade $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion
}

function checkClusterControlPlaneNeedsUpgrade() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4

    if [ $(helperCheckSemVer $__clusterK8sVersion) -lt $(helperCheckSemVer $__targetK8sVersion) ]
    then
        echo "Control Plane Upgrade needed."
        echo "Control Plane version equal to: $__clusterK8sVersion"
        echo "Target K8s $__targetK8sVersion"
        
        upgradeClusterControlPlane $__RG $__clusterName $__targetK8sVersion
        
        if [ $? -eq 0 ]
        then
            return 0
        else
            echo "Control Plane Upgrade Failed." >> $TEMP_FOLDER$ERR_LOG_FILE_NAME
            return 1
        fi
    else 
        echo "Control Plane Upgrade not needed."
        echo "Control Plane version equal to: $__clusterK8sVersion."
        echo "Target K8s $__targetK8sVersion"

        return 1
    fi
}

function upgradeClusterControlPlane() {
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

    if [ $? -eq 0 ]
    then
        echo "Succeeded: Control Plane Upgrade Complete now at version $__K8SVersion"
        echo "Finished at: $(date)"
        return 0
    else 
        echo "Failed: Control Plane Upgrade to version $__K8SVersion"
        return 1
    fi
    
}

function upgradeAllClustersAndNodePools() {
    for __clusterName in $(cat "$TEMP_FOLDER/$CLUSTER_FILE_NAME" | jq -r '.[] | .name')
    do
        upgradeNodePoolsInCluster $__clusterName
    done
}