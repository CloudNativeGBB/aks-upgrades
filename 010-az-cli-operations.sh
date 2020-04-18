#! /bin/bash

function setSubscription(){
    echo "Setting target AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"

    az account set --subscription $1

    if [ $? -eq 0 ]
    then
        echo "$(date)   Succeeded to set AZURE_SUBSCRIPTION_ID to: $AZURE_SUBSCRIPTION_ID"
        
    else
        echo "$(date)   Failed to set AZURE_SUBSCRIPTION_ID to: $AZURE_SUBSCRIPTION_ID" >err.log
        return 1
    fi
}