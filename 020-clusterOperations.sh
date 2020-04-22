#! /bin/bash

# Expected variables to be exported by calling script(s):
# $UPDATE_TO_KUBERNETES_VERSION
# $CLUSTERS_FILE_NAME

## Load nodePool Level Operation functions
source "./030-nodePoolOperations.sh"

### Cluster functions
function createClusterUpgradeCandidatesJSON(){
    echo "Generating list of AKS CLusters to upgrade..."
    local __candidatesSummaryDetails=$(az aks list --query "[].{name: name, kubernetesVersion: kubernetesVersion, resourceGroup: resourceGroup, agentPoolProfiles: agentPoolProfiles[?orchestratorVersion < '$UPDATE_TO_KUBERNETES_VERSION' && osType == 'Linux' && mode == 'User'].{count:count, name: name, mode: mode, vmSize: vmSize, orchestratorVersion:orchestratorVersion }}" -o json)
    echo $__candidatesSummaryDetails > "$TEMP_FOLDER/$CLUSTERS_FILE_NAME"

    if [ $? -eq 0 ]
    then
        echo "Succeeded to create list of cluster upgrade candidates"
        removeClustersFromUpgradeCandidatesJSON
        if [ $? -eq 0 ]
        then
            return 0
        else 
            return 1
        fi
    else
        echo "Failed to create list of cluster upgrade candidates" >> $TEMP_FOLDER$ERR_LOG_FILE_NAME
        return 1
    fi
}

function removeClustersFromUpgradeCandidatesJSON() {
    local __excludedClusterArray=(${EXCLUDED_CLUSTER_LIST:-$1})
    local __clustersFileJSON="$TEMP_FOLDER$CLUSTERS_FILE_NAME"

    if [ -z "$__excludedClusterArray" ]
    then
        echo "No clusters remove from list of cluster upgrade candidates"
        return 0
    else
        echo "Removing clusters: $__excludedClusterArray"
        echo "fails here"
        for __excludedCluster in "${__excludedClusterArray[@]}"
        do
            echo "fails here2"
            local __arr=($(echo $__excludedCluster | tr ":" " "))

            # Using messey array syntax to make array indexes consistent between bash &
            local __RG="${__arr[@]:0:1}"
            local __clusterName="${__arr[@]:1:1}"

            removeClusterFromClusterUpgradeCandidatesJSON $__RG $__clusterName
        done
    fi
}

function removeClusterFromClusterUpgradeCandidatesJSON() {
    local __RG=$1
    local __clusterName=$1

    cp "$TEMP_FOLDER$CLUSTERS_FILE_NAME" "$TEMP_FOLDER$CLUSTERS_FILE_NAME.original.backup"
    echo "fails here3"
    cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME.original.backup" \
        | jq -r --arg RG "$__RG" --arg clusterName "$__clusterName" '[.[] | select((.name!=$RG) and (.resourceGroup!=$clusterName))]' \
        > "$TEMP_FOLDER$CLUSTERS_FILE_NAME.new"
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

function checkAndUpgradeAllClusterControlPlanes() {
    checkAllClusterControlPlanes 0
}

function checkAllClusterControlPlanes() {
    local __upgradeControlPlane="${1:-1}"

    for __clusterName in $(cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME" | jq -r '.[] | .name')    
    do
        local __RG=$(cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME" | jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).resourceGroup')
        local __clusterK8sVersion=$(cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME" | jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).kubernetesVersion')
        local __targetK8sVersion=$UPDATE_TO_KUBERNETES_VERSION
        
        checkClusterControlPlane $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion $__upgradeControlPlane
    done
}

function checkAndUpgradeClusterControlPlane() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4

    checkClusterControlPlane $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion 0
}

function checkClusterControlPlane() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4
    local __upgradeControlPlane="${5:-1}"

    checkClusterControlPlaneNeedsUpgrade $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion $__upgradeControlPlane
}

function checkClusterControlPlaneNeedsUpgrade() {
    local __RG=$1
    local __clusterName=$2
    local __clusterK8sVersion=$3
    local __targetK8sVersion=$4
    local __upgradeControlPlane="${5:-1}"

    if [ $(helperCheckSemVer $__clusterK8sVersion) -lt $(helperCheckSemVer $__targetK8sVersion) ]
    then
        echo "Control Plane Upgrade needed for cluster $__clusterName."
        echo "Current Cluster version equal to: $__clusterK8sVersion"
        echo "Target Cluster version K8s $__targetK8sVersion"
        
        if [ "$__upgradeControlPlane" -eq 0 ]
        then
            upgradeClusterControlPlane $__RG $__clusterName $__targetK8sVersion
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

    echo "Upgrading Cluster $__clusterName Control Plane to K8s v.$__K8SVersion"
    echo "Started at: $(date)"
    
    az aks upgrade \
        -g $__RG \
        -n $__clusterName \
        -k $__K8SVersion \
        --control-plane-only \
        --yes

    if [ $? -eq 0 ]
    then
        echo "Succeeded: Upgraded Cluster $__clusterName Control Plane to K8s v.$__K8SVersion"
        echo "Finished at: $(date)"
        return 0
    else 
        echo "Failed: Control Plane Upgrade to v.$__K8SVersion"
        return 1
    fi
    
}

function checkAndRollingUpgradeAllClustersAndNodePools() {
    for __clusterName in $(cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME" | jq -r '.[] | .name')
    do
        local __RG=$(cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME"| jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).resourceGroup')
        local __clusterK8sVersion=$(cat "$TEMP_FOLDER$CLUSTERS_FILE_NAME"| jq -r --arg clusterName "$__clusterName" '.[] | select(.name==$clusterName).kubernetesVersion')
        local __targetK8sVersion=$UPDATE_TO_KUBERNETES_VERSION

        getClusterCredentials $__RG $__clusterName
        setClusterConfigContext $__clusterName
        checkAndUpgradeClusterControlPlane $__RG $__clusterName $__clusterK8sVersion $__targetK8sVersion

        if [ $? -eq 0 ]
        then
            upgradeNodePoolsInCluster $__clusterName
        fi
    done
}

function getClusterCredentials() {
    local __RG=$1
    local __clusterName=$2

    # Get Kube Config Creds and overwrite if already exists (No User Prompts)
    az aks get-credentials -g $__RG -n $__clusterName --overwrite-existing
}

function setClusterConfigContext() {
    local __clusterName=$1

    kubectl config set-context $__clusterName
}