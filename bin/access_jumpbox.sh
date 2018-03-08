#!/bin/bash
#
# Automating bbl
set -e
#set -x
AJB_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOY_DIR=${DEPLOY_DIR:-"deploy"}


# this script assumes the presence of certain files in the same directory as the executable
# Ensure that the $CWD is where the executable is
function access_jumpbox () {
  cd "${DEPLOY_DIR}"
  # Let's start with access info
  JUMPBOX_ADDRESS=$(bbl jumpbox-address)
  SSH_KEY_FILE=${DEPLOY_DIR}/ssh-key
  rm -f ${SSH_KEY_FILE}
  bbl ssh-key > ${SSH_KEY_FILE}
  chmod 400 ${SSH_KEY_FILE}

  ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_FILE} jumpbox@$JUMPBOX_ADDRESS "$(typeset -f configure_jumpbox); configure_jumpbox"
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
