#!/bin/bash
#
# Automating bbl on Azure
set -e

read -p "Azure username: " AZURE_USERNAME
read -s -p "Azure password: " AZURE_PASSWORD
echo
read -p "Deployment name: " NAME
read -p "Azure region: " AZ_REG
read -p "Remote access app name: " APP_NAME
read -p "Remote access app URI (use http://blah): " APP_URI
read -p "Remote access app homepage (use http://blah): " APP_HOMEPAGE
read -p "Your domain name (omit http://): " KEY_DOMAIN_NAME
read -s -p "Private key password: " KEY_PASSWORD
echo
read -p "Enter in your Country: " COUNTRY
read -p "Enter in your State (full name): " STATE
read -p "Enter in your City: " CITY
read -p "Enter in your Company Name: " ORGANIZATION
read -p "Enter in your Department: "  DEPARTMENT
read -p "Enter in your Domain Name: " DOMAIN_NAME

# Log into Azure & set environment info
az login -u $AZURE_USERNAME -p $AZURE_PASSWORD

AZ_TEN_ID=$(az account list | jq -r '.[0].tenantId')
AZ_SUB_ID=$(az account list | jq -r '.[0].id')

# Create app registration, set access info, change permissions
az ad app create --display-name "$APP_NAME" \
--password client-secret \
--identifier-uris "$APP_URI" \
--homepage "$APP_HOMEPAGE"

AZ_CLI_ID=$(az ad app show --id $APP_URI | jq -r '.appId')
AZ_CLI_SECRET=$(az ad app show --id $APP_URI | jq -r '.additionalProperties.passwordCredentials[0].keyId')

az ad sp create --id $AZ_CLI_ID
sleep 30s # sleep 30s because https://github.com/Azure/azure-powershell/issues/655
az role assignment create --role "Owner" --assignee "$APP_URI" --scope "/subscriptions/$AZ_SUB_ID"

# Create & save keys for the Application Gateway
openssl genrsa -out $KEY_DOMAIN_NAME.key 2048
openssl req -new -x509 -days 365 \
-key $KEY_DOMAIN_NAME.key -out $KEY_DOMAIN_NAME.crt \
-subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$DEPARTMENT/CN=$DOMAIN_NAME"

openssl pkcs12 -export -out PFX_FILE -inkey $KEY_DOMAIN_NAME.key -in $KEY_DOMAIN_NAME.crt -password pass:$KEY_PASSWORD
echo $KEY_PASSWORD > PFX_FILE_PASS

az login --service-principal  -u $APP_URI -p $AZ_CLI_SECRET --tenant $AZ_TEN_ID

# Generate local files & fix them
bbl plan --iaas azure \
--name $NAME \
--azure-subscription-id $AZ_SUB_ID \
--azure-tenant-id $AZ_TEN_ID \
--azure-client-id $AZ_CLI_ID \
--azure-client-secret $AZ_CLI_SECRET \
--azure-region $AZ_REG \
--lb-type cf \
--lb-cert PFX_FILE \
--lb-key PFX_FILE_PASS \
--debug

az network nic list | jq -r '.[].ipConfigurations[].privateIpAddress' | sort
echo "Above is a list of used IP addresses across your Azure subscription."
read -p "Pick an unused CIDR for the deployment (use format x.x.x.x/xx): " CUSTOM_CIDR

echo "system_domain=$DOMAIN_NAME" >> ./vars/bbl.tfvars
echo "network_cidr=$CUSTOM_CIDR" >> ./vars/bbl.tfvars
echo "internal_cidr=$CUSTOM_CIDR" >> ./vars/bbl.tfvars

# Deploy
bbl up --iaas azure \
--name $NAME \
--azure-subscription-id $AZ_SUB_ID \
--azure-tenant-id $AZ_TEN_ID \
--azure-client-id $AZ_CLI_ID \
--azure-client-secret $AZ_CLI_SECRET \
--azure-region $AZ_REG \
--lb-type $cf \
--lb-cert PFX_FILE \
--lb-key PFX_FILE_PASS \
--debug

# Log into jumpbox and install CLIs, configure BOSH director
