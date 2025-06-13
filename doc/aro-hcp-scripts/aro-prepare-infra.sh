export AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
if [ ! -f sp.json ] ; then
    let "randomIdentifier=$RANDOM*$RANDOM"
    servicePrincipalName="msdocs-sp-$randomIdentifier"
    roleName="Contributor"
    echo "Creating SP for RBAC with name $servicePrincipalName, with role $roleName and in scopes /subscriptions/$AZURE_SUBSCRIPTION_ID"
    az ad sp create-for-rbac --name $servicePrincipalName --role $roleName --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID > sp.json
fi
export AZURE_TENANT_ID=$(jq -r .tenant sp.json)
export AZURE_CLIENT_ID=$(jq -r .appId sp.json)
export AZURE_CLIENT_SECRET=$(jq -r .password sp.json)
export REGION=${REGION:-westus3}
export NAME_PREFIX=${NAME_PREFIX:-aro-hcp}

export CLUSTER_TOPOLOGY=true
export AZURE_CLIENT_ID_USER_ASSIGNED_IDENTITY=$AZURE_CLIENT_ID # for compatibility with CAPZ v1.16 templates

# Settings needed for AzureClusterIdentity used by the AzureCluster
export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
export CLUSTER_IDENTITY_NAME="cluster-identity"
export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"

# we need to define list of crds to install
export ADDITIONAL_ASO_CRDS='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*;network.azure.com/*;authorization.azure.com/*'

# Create a secret to include the password of the Service Principal identity created in Azure
# This secret will be referenced by the AzureClusterIdentity used by the AzureCluster
oc create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}" --namespace "${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}"

# Finally, initialize the management cluster
clusterctl init --infrastructure azure

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
 name: aso-credential
 namespace: default
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID: "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
 AZURE_CLIENT_SECRET: "$AZURE_CLIENT_SECRET"
EOF

