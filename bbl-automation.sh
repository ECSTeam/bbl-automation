#!/bin/bash
#
# Automating bbl
set -e
set -x

function deploy_on_azure () {
  echo "Let's start with some Azure basics:"
  read -p "Azure username: " AZURE_USERNAME
  read -s -p "Azure password: " AZURE_PASSWORD
  echo
  read -p "Deployment name: " NAME
  echo "For a list of regions, run:"
  echo "az account list-locations | jq -r '.[].name'"
  read -p "Azure region: " AZ_REG
  read -p "Remote access app name: " APP_NAME
  echo "Let's create a key for the Application Gateway:"
  read -s -p "Pick a private key password: " KEY_PASSWORD
  echo
  read -p "Enter your Country: " COUNTRY
  read -p "Enter your State (full name): " STATE
  read -p "Enter your City: " CITY
  read -p "Enter your Company Name: " ORGANIZATION
  read -p "Enter your Department: "  DEPARTMENT
  read -p "Enter your Domain Name: " DOMAIN_NAME
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
  echo "bbl will not properly deploy if you specify a range smaller than /16 (/24, for example)."
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

  sleep 60s
  access_jumpbox
}

function deploy_on_aws () {
  echo "Let's start with some AWS basics:"
  read -p "Name your deployment: " NAME
  read -p "Your aws_access_key_id: " ACCESS_KEY_ID
  read -s -p "Your aws_secret_access_key: " ACCESS_SECRET_KEY
  echo
  read -p "Deployment region: " DEP_REGION
  read -p "Your preferred output format (json, text, table): " PREF_FORMAT

  echo "[default]" >> ~/.aws/credentials
  echo "aws_access_key_id=$ACCESS_KEY_ID" >> ~/.aws/credentials
  echo "aws_secret_access_key=$ACCESS_SECRET_KEY" >> ~/.aws/credentials

  echo "[default]" >> ~/.aws/config
  echo "region=$DEP_REGION" >> ~/.aws/config
  echo "output=$PREF_FORMAT" >> ~/.aws/config

  aws iam create-user --user-name "bbl-user"
  aws iam put-user-policy --user-name "bbl-user" \
  	--policy-name "bbl-policy" \
  	--policy-document file://policy

  AWS_KEY=$(aws iam create-access-key --user-name "bbl-user")

  bbl up \
	--aws-access-key-id $ACCESS_KEY_ID \
	--aws-secret-access-key $ACCESS_SECRET_KEY \
	--aws-region $DEP_REGION \
	--iaas aws
  --name $NAME

  sleep 60s
  access_jumpbox
}

function deploy_on_gcp () {
  echo "Google Cloud is not supported at the moment."
  exit 1
}

function access_jumpbox () {
  # Let's start with access info
  JUMPBOX_ADDRESS=$(bbl jumpbox-address)
  bbl ssh-key > key
  chmod 400 key

  ssh -o StrictHostKeyChecking=no -i ./key jumpbox@$JUMPBOX_ADDRESS "$(typeset -f configure_jumpbox); configure_jumpbox"
}

function configure_jumpbox () {
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get install -y build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3 git nano vim
  wget https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.48-linux-amd64
  chmod +x bosh-cli-*
  sudo mv bosh-cli-* /usr/local/bin/bosh

  # paste contents of director-vars-store.yml and run bosh alias-env your-bosh-alias -e bosh-director-ip-address --ca-cert <(bosh int ./your-created-file.yml --path /director_ssl/ca) to target the director
  # log into bosh director with the username admin and password stored in bbl-state.json
  echo "You're ready to go!"

}

read -p "Pick an IAAS - azure, aws, or gcp: " IAAS

if [ $IAAS == "azure" ]; then deploy_on_azure
elif [ $IAAS == "aws" ]; then deploy_on_aws
elif [ $IAAS == "gcp" ]; then deploy_on_gcp
else echo "Try 'aws', 'azure', or 'gcp' as valid inputs."
  exit 1
fi
