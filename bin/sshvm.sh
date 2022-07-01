#!/usr/bin/env zsh

#https://ystatit.medium.com/azure-ssh-into-aks-nodes-471c07ad91ef
#https://docs.microsoft.com/en-us/azure/aks/node-access


resource_group=$(az group list --query "[?location=='westeurope']" -o json| jq ".[0].name")
cluster_name=$(az resource list -g ${resource_group} -o json|jq -r '.[]|select(.name|startswith("akscluster"))|.name')