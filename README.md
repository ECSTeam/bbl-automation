# bbl-automation

Use this script to automate bbl's jumpbox and BOSH director install on various cloud platforms. It will also install bosh-cli in the jumpbox after creating it.

### Prerequisites
- Install the Command Line Interface for the desired IaaS
  - \[[Azure](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)\]
  - \[[AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html)\] 
  - \[[GCP](https://cloud.google.com/sdk/downloads)\]
- Mac OS will require the installation of [brew](https://brew.sh/)
- Install the prerequisites defined in [cloudfoundry/bosh-bootloader](https://github.com/cloudfoundry/bosh-bootloader/blob/master/README.md "bbl GitHub Repo Page")

