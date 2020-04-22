# AKS Cluster Upgrades (DEMO ONLY - Not for Production)

**NOTE:** This is **NOT** meant for production and is **NOT** supported.

This repository attempts to show how to do an in-place K8s version Cluster Control Plane and Node Pool upgrade.  

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
    