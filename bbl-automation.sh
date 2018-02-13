#!/bin/bash
#
# Automating bbl
set -e
# set -x

function deploy_on_azure () {
  echo "Let's start with some Azure basics:"
  read -p "Azure username: " AZURE_USERNAME
  read -s -p "Azure password: " AZURE_PASSWORD
  echo
  read -p "Deployment name: " NAME
  read -p "Azure region: " AZ_REG
  read -p "Remote access app name: " APP_NAME
  echo "Let's create a key for the Application Gateway:"
  read -s -p "Private key password: " KEY_PASSWORD
  echo
  read -p "Enter in your Country: " COUNTRY
  read -p "Enter in your State (full name): " STATE
  read -p "Enter in your City: " CITY
  read -p "Enter in your Company Name: " ORGANIZATION
  read -p "Enter in your Department: "  DEPARTMENT
  read -p "Enter in your Domain Name: " DOMAIN_NAME
  echo "Here we go!"

  APP_ACCESS="http://$APP_NAME"

  # Log into Azure & set environment info
  az login -u $AZURE_USERNAME -p $AZURE_PASSWORD

  AZ_TEN_ID=$(az account list | jq -r '.[0].tenantId')
  AZ_SUB_ID=$(az account list | jq -r '.[0].id')

  # Create app registration, set access info, change permissions
  az ad app create --display-name "$APP_NAME" \
  --password password \
  --identifier-uris "$APP_ACCESS" \
  --homepage "$APP_ACCESS"

  AZ_CLI_ID=$(az ad app show --id $APP_ACCESS | jq -r '.appId')

  az ad sp create --id $AZ_CLI_ID
  sleep 60s # sleep 60s because https://github.com/Azure/azure-powershell/issues/655
  az role assignment create --role "Owner" --assignee $AZ_CLI_ID --scope "/subscriptions/$AZ_SUB_ID"

  # Create & save keys for the Application Gateway
  openssl genrsa -out $KEY_DOMAIN_NAME.key 2048
  openssl req -new -x509 -days 365 \
  -key $KEY_DOMAIN_NAME.key -out $KEY_DOMAIN_NAME.crt \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$DEPARTMENT/CN=$DOMAIN_NAME"

  openssl pkcs12 -export -out lbcert -inkey $KEY_DOMAIN_NAME.key -in $KEY_DOMAIN_NAME.crt -password pass:$KEY_PASSWORD
  echo $KEY_PASSWORD > lbkey

  # Generate local files & fix them
  bbl plan --iaas azure \
  --name $NAME \
  --azure-subscription-id $AZ_SUB_ID \
  --azure-tenant-id $AZ_TEN_ID \
  --azure-client-id $AZ_CLI_ID \
  --azure-client-secret password \
  --azure-region $AZ_REG \
  --lb-type cf \
  --lb-cert lbcert \
  --lb-key lbkey \
  --debug

  az network nic list | jq -r '.[].ipConfigurations[].privateIpAddress' | sort
  echo "Above is a list of used IP addresses across your Azure subscription."
  read -p "Pick an unused CIDR for the deployment (use format x.x.x.x/xx): " CUSTOM_CIDR

  echo "system_domain=\"fake.domain\"" >> ./vars/bbl.tfvars
  echo "network_cidr=\"$CUSTOM_CIDR\"" >> ./vars/bbl.tfvars
  echo "internal_cidr=\"$CUSTOM_CIDR\"" >> ./vars/bbl.tfvars

  # Deploy
  bbl up --iaas azure \
  --name $NAME \
  --azure-subscription-id $AZ_SUB_ID \
  --azure-tenant-id $AZ_TEN_ID \
  --azure-client-id $AZ_CLI_ID \
  --azure-client-secret password \
  --azure-region $AZ_REG \
  --lb-type cf \
  --lb-cert lbcert \
  --lb-key lbkey \
  --debug
}

function deploy_on_aws () {
  echo "AWS is not supported at the moment."
  exit 1
}

function deploy_on_gcp () {
  echo "Google Cloud is not supported at the moment."
  exit 1
}

function configure_jumpbox () {
  echo "Coming soon!"
}

read -p "Pick an IAAS - azure, aws, or gcp: " IAAS

if [ $IAAS == "azure" ]; then deploy_on_azure
elif [ $IAAS == "aws" ]; then deploy_on_aws
elif [ $IAAS == "gcp" ]; then deploy_on_gcp
else echo "Try 'aws', 'azure', or 'gcp' as valid inputs."
  exit 1
fi
