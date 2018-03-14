#!/bin/bash
#
# Automating bbl
set -e
#set -x
AWS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOY_DIR=${DEPLOY_DIR:-"deploy"}
SELECTED_PROFILE=${SELECTED_PROFILE:-default}

function retrieveAwsCredentialsAndConfig()
{
  echo "Using ${SELECTED_PROFILE} profile of ~/.aws/credentials and ~/.aws/config"

  . ${AWS_SCRIPT_DIR}/read_config.sh ~/.aws/credentials
  declare "ACCESS_KEY_ID_var=aws_access_key_id[${SELECTED_PROFILE}]"
  ACCESS_KEY_ID="${!ACCESS_KEY_ID_var}"
  declare "ACCESS_SECRET_KEY_var=aws_secret_access_key[${SELECTED_PROFILE}]"
  ACCESS_SECRET_KEY=${!ACCESS_SECRET_KEY_var}

  . ${AWS_SCRIPT_DIR}/read_config.sh ~/.aws/config
  declare "DEP_REGION_var=region[${SELECTED_PROFILE}]"
  DEP_REGION="${!DEP_REGION_var}"
  declare "PREF_FORMAT_var=output[${SELECTED_PROFILE}]"
  PREF_FORMAT=${!PREF_FORMAT_var}

}

function deploy_on_aws () {
  mkdir -p ${DEPLOY_DIR}
  DEPLOY_DIR="$( cd ${DEPLOY_DIR}  && pwd )"
  cd ${DEPLOY_DIR}
  pwd

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
    echo "Assigning aws-bbl-policy to $BBL_USER. "
    echo "====================================================================="
    aws iam put-user-policy --user-name ${BBL_USER} \
      --policy-name "bbl-policy" \
      --policy-document file://${AWS_SCRIPT_DIR}/../template/aws-bbl-policy
    aws iam list-user-policies --user-name $BBL_USER
  else
    echo "====================================================================="
    echo "$BBL_USER has aws-bbl-policy. Skipping aws-bbl-policy creation/assignment step."
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

