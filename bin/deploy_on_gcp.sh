#!/bin/bash
#
# Automating bbl
GCP_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOY_DIR=${DEPLOY_DIR:-"deploy"}


function deploy_on_gcp () {
  echo "Google Cloud is not supported at the moment."
  exit 1
}