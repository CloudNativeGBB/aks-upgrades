# AKS Cluster Upgrades (DEMO ONLY - Not for Production)

**NOTE:** This is **NOT** meant for production and is **NOT** supported.

This repository attempts to show how to do an in-place K8s version Cluster Control Plane and Node Pool upgrade.

Upgrades are done in an inplace rolling update manner.
1. Based on ```$UPDATE_TO_KUBERNETES_VERSION``` environment variable clusters with Node Pools older than the specified value will be added to an upgrades candidates file specified by ```$CLUSTERS_FILE_NAME``` in ```$TEMP_FOLDER``` directory
1. If you explicitly add clusters to ```$EXCLUDED_CLUSTERS_LIST``` array, then these clusters will be skipped (removed from the list, after initial list generation)
1. Clusters are then updated one-by-one accordingly
    1. Control Plane API version is checked and upgraded as needed
    1. Node Pools within the current cluster with versions older than specified version are "upgraded" (Blue/Green Node Pool Upgrade)
        1. New Node Pool is created with same ```vmSize``` and node ```count``` values as Old (aka Current) Node Pool
        1. New Node Pool is given a name of ```oldNodePoolName``` + suffix of ```vMMmmppp``` where ```v``` is the delimiter used for ```MMmmpppp``` which follows the targetted K8s semver of ```MM.mm.ppp```
        1.  Once the new Node Pool is created, Old Node Pool is:
            1. Tainted to stop any new workloads from being scheduled
            2. Drained of existing workoads
            3. Deleted

## Required Tools
- Linux (preferred)/MacOS with bash or zsh
- (Azure-CLI)[https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest]
- (jq)[https://stedolan.github.io/jq/]
- (kubectl)[https://kubernetes.io/docs/tasks/tools/install-kubectl/]

## Optional Tools
- [Azure DevOps](https://dev.azure.com)
    - A sample [```azure-pipelines.yaml```](./azure-pipelines.yaml) file is included to help facilitate automatic execution of the upgrade process by updating the env vars listed in the yaml file

## Required Environment Variables/Settings
- Must be logged into Azure CLI with an account (user or service principal) that has the ability to update resources in your given subscription
- **ENVIRONMENT VARIABLES:**
    - ```UPDATE_TO_KUBERNETES_VERSION``` must be set
        - currently this will default to ```1.16.7``` but this default will be removed in future versions
        - This is the main driving force/trigger to create an update
        - Order of prescedence:
            - edit value directly in ```main.sh``` script
            - edit value in Environment Variable (must ```export UPDATE_TO_KUBERNETES_VERSION="MM.mm.pppp"```)

## Optional Environment Variables/Settings

- ```$TEMP_FOLDER```
    - default: ```.tmp/``` - must include trailing slash
    - Folder where script stores temp files to.  Will be deleted on each subsequent script start via helper function ```helperClearTempFiles()```
- ```$CLUSTERS_FILE_NAME```
    - default: "clusterUpgradeCandidatesSummary.json"
    - File where JSON of all eligible clusters for upgrade are stored. Saved to the temp folder specificed by ```$TEMP_FOLDER```
- ```$ERR_LOG_FILE_NAME```
    - default: "err.log"
    - File where errors are appended to during script run. Saved to the temp folder specificed by ```$TEMP_FOLDER```
- ```$EXCLUDED_CLUSTERS_LIST```
    - default: ```empty```
    - format:   ```( cluster-rg-1:cluster-name-1 clsuter-rg-2:cluster-name-2 cluster-rg-N:cluster-name-N )```
    - Optionally add clusters to an opt-out/excluded list from upgrades
    