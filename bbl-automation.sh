#!/bin/bash
#
# Automating bbl
set -e


#set -x
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="${SCRIPT_DIR}/bin"
source ${BIN_DIR}/array_menu.sh
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

function retrieveAwsCredentialsAndConfig()
{
  echo "Using ${SELECTED_PROFILE} profile of ~/.aws/credentials and ~/.aws/config"

  . ${BIN_DIR}/read_config.sh ~/.aws/credentials
  declare "ACCESS_KEY_ID_var=aws_access_key_id[${SELECTED_PROFILE}]"
  ACCESS_KEY_ID="${!ACCESS_KEY_ID_var}"
  declare "ACCESS_SECRET_KEY_var=aws_secret_access_key[${SELECTED_PROFILE}]"
  ACCESS_SECRET_KEY=${!ACCESS_SECRET_KEY_var}

  . ${BIN_DIR}/read_config.sh ~/.aws/config
  declare "DEP_REGION_var=region[${SELECTED_PROFILE}]"
  DEP_REGION="${!DEP_REGION_var}"
  declare "PREF_FORMAT_var=output[${SELECTED_PROFILE}]"
  PREF_FORMAT=${!PREF_FORMAT_var}

}

function deploy_on_aws () {

  #If the user has a preferred bbl-user, use that, otherwise default it
  export HOLD_BBL_USER=${BBL_USER:-"bbl-user"}

  echo "Let's start with some AWS basics:"
  read -p "Name your deployment: " NAME
  read -p "bbl user ID[${HOLD_BBL_USER}]: " BBL_USER
  export BBL_USER=${BBL_USER:-${HOLD_BBL_USER}}

  echo
  SELECTED_PROFILE=default
#  aws configure --profile ${SELECTED_PROFILE}
  aws configure

  retrieveAwsCredentialsAndConfig

  if aws iam get-user --user-name $BBL_USER 2>/dev/null
  then
    echo "====================================================================="
    echo "$BBL_USER previously existed. Skipping creation step."
    echo "====================================================================="
  else
    echo "====================================================================="
    echo "Creating bbl user: $BBL_USER"
    echo "====================================================================="
    aws iam create-user --user-name ${BBL_USER}
  fi

  if [ -z $( aws iam list-user-policies --user-name $BBL_USER --output text --query PolicyNames|grep bbl-policy ) ]
  then
    echo "====================================================================="
    echo "Assigning bbl-policy to $BBL_USER. "
    echo "====================================================================="
    aws iam put-user-policy --user-name ${BBL_USER} \
      --policy-name "bbl-policy" \
      --policy-document file://${SCRIPT_DIR}/policy
    aws iam list-user-policies --user-name $BBL_USER
  else
    echo "====================================================================="
    echo "$BBL_USER has bbl-policy. Skipping policy creation/assignment step."
    echo "====================================================================="
  fi

  AWS_KEY=$(aws iam create-access-key --user-name ${BBL_USER})

  bbl up \
	--aws-access-key-id $ACCESS_KEY_ID \
	--aws-secret-access-key $ACCESS_SECRET_KEY \
	--aws-region $DEP_REGION \
	--iaas aws \
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
  rm -f ${SCRIPT_DIR}/key
  bbl ssh-key > ${SCRIPT_DIR}/key
  chmod 400 ${SCRIPT_DIR}/key

  ssh -o StrictHostKeyChecking=no -i ${SCRIPT_DIR}/key jumpbox@$JUMPBOX_ADDRESS "$(typeset -f configure_jumpbox); configure_jumpbox"
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

echo  "Pick an IAAS - azure, aws, or gcp: "
IAAS_OPTIONS=(azure aws gcp)
createMenu "${#IAAS_OPTIONS[@]}" "${IAAS_OPTIONS[@]}"
IAAS=$MENU_SELECTION_POSITION

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

#read -p "Pick an IAAS - azure, aws, or gcp: " IAAS
#if [ $IAAS == "azure" ]; then deploy_on_azure
#elif [ $IAAS == "aws" ]; then deploy_on_aws
#elif [ $IAAS == "gcp" ]; then deploy_on_gcp
#else echo "Try 'aws', 'azure', or 'gcp' as valid inputs."
#  exit 1
#fi
