#!/bin/bash
#
# Automating bbl
set -e


#set -x
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="${SCRIPT_DIR}/bin"
source ${BIN_DIR}/array_menu.sh
source ${BIN_DIR}/access_jumpbox.sh
source ${BIN_DIR}/deploy_on_aws.sh
source ${BIN_DIR}/deploy_on_gcp.sh
DEPLOY_DIR=${DEPLOY_DIR:-"deploy"}


MENU_SELECTION_POSITION=-1
MENU_SELECTION=''

# this script assumes the presence of certain files in the same directory as the executable
# Ensure that the $CWD is where the executable is
cd "${SCRIPT_DIR}"

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

function displayUsage()
{
  echo "Usage: "$(basename $0)" [-d <deployDir>] [-i <desired iaas>]"
}

IAAS=""

while getopts ":d:i:" opt; do
  case ${opt} in
    d)
      DEPLOY_DIR=$OPTARG
      ;;
    i)
      IAAS=$OPTARG
      ;;
    \?)
      displayUsage
      exit 1
      ;;
  esac
done
echo ${DEPLOY_DIR}
mkdir -p ${DEPLOY_DIR}
DEPLOY_DIR="$( cd ${DEPLOY_DIR}  && pwd )"

IAAS_OPTIONS=( azure aws gcp )
if [ -z $( printf '%s\n' "${IAAS_OPTIONS[@]}"|grep -w $IAAS ) ]
then
  echo  "Pick an IAAS - azure, aws, or gcp: "
  createMenu "${#IAAS_OPTIONS[@]}" "${IAAS_OPTIONS[@]}"
  IAAS=$MENU_SELECTION_POSITION
else
  MENU_SELECTION=$IAAS
  IAAS=$( printf '%s\n' "${IAAS_OPTIONS[@]}"|grep -nw $IAAS|cut -d":" -f1 )
fi

case $IAAS in
1)
  echo "Beginning $MENU_SELECTION process"
  deploy_on_azure
  ;;
2)
  echo "Beginning $MENU_SELECTION process"
  deploy_on_aws
  ;;
3)
  echo "Beginning $MENU_SELECTION process"
  deploy_on_gcp
  ;;
*)
  echo "No valid option selected"
  exit 1
  ;;
esac
