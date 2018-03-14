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
declare STATES_OPTIONS=( "Alabama" "Alaska" "Arizona" "Arkansas" "California" "Colorado" "Connecticut" "Delaware" "Florida" "Georgia" "Hawaii" "Idaho" "Illinois" "Indiana" "Iowa" "Kansas" "Kentucky" "Louisiana" "Maine" "Maryland" "Massachusetts" "Michigan" "Minnesota" "Mississippi" "Missouri" "Montana" "Nebraska" "Nevada" "New Hampshire" "New Jersey" "New Mexico" "New York" "North Carolina" "North Dakota" "Ohio" "Oklahoma" "Oregon" "Pennsylvania" "Rhode Island" "South Carolina" "South Dakota" "Tennessee" "Texas" "Utah" "Vermont" "Virginia" "Washington" "West Virginia" "Wisconsin" "Wyoming" "American Samoa" "District of Columbia" "Guam" "Northern Mariana Islands" "Puerto Rico" "United States Virgin Islands")
declare COUNTRY_OPTIONS=( "(US) United States of America" "(CA) Canada" "(AX) Åland Islands" "(AD) Andorra" "(AE) United Arab Emirates" "(AF) Afghanistan" "(AG) Antigua and Barbuda" "(AI) Anguilla" "(AL) Albania" "(AM) Armenia" "(AN) Netherlands Antilles" "(AO) Angola" "(AQ) Antarctica" "(AR) Argentina" "(AS) American Samoa" "(AT) Austria" "(AU) Australia" "(AW) Aruba" "(AZ) Azerbaijan" "(BA) Bosnia and Herzegovina" "(BB) Barbados" "(BD) Bangladesh" "(BE) Belgium" "(BF) Burkina Faso" "(BG) Bulgaria" "(BH) Bahrain" "(BI) Burundi" "(BJ) Benin" "(BM) Bermuda" "(BN) Brunei Darussalam" "(BO) Bolivia" "(BR) Brazil" "(BS) Bahamas" "(BT) Bhutan" "(BV) Bouvet Island" "(BW) Botswana" "(BZ) Belize" "(CA) Canada" "(CC) Cocos (Keeling) Islands" "(CF) Central African Republic" "(CH) Switzerland" "(CI) Cote D'Ivoire (Ivory Coast)" "(CK) Cook Islands" "(CL) Chile" "(CM) Cameroon" "(CN) China" "(CO) Colombia" "(CR) Costa Rica" "(CS) Czechoslovakia (former)" "(CV) Cape Verde" "(CX) Christmas Island" "(CY) Cyprus" "(CZ) Czech Republic" "(DE) Germany" "(DJ) Djibouti" "(DK) Denmark" "(DM) Dominica" "(DO) Dominican Republic" "(DZ) Algeria" "(EC) Ecuador" "(EE) Estonia" "(EG) Egypt" "(EH) Western Sahara" "(ER) Eritrea" "(ES) Spain" "(ET) Ethiopia" "(FI) Finland" "(FJ) Fiji" "(FK) Falkland Islands (Malvinas)" "(FM) Micronesia" "(FO) Faroe Islands" "(FR) France" "(FX) France, Metropolitan" "(GA) Gabon" "(GB) Great Britain (UK)" "(GD) Grenada" "(GE) Georgia" "(GF) French Guiana" "(GG) Guernsey" "(GH) Ghana" "(GI) Gibraltar" "(GL) Greenland" "(GM) Gambia" "(GN) Guinea" "(GP) Guadeloupe" "(GQ) Equatorial Guinea" "(GR) Greece" "(GS) S. Georgia and S. Sandwich Isls." "(GT) Guatemala" "(GU) Guam" "(GW) Guinea-Bissau" "(GY) Guyana" "(HK) Hong Kong" "(HM) Heard and McDonald Islands" "(HN) Honduras" "(HR) Croatia (Hrvatska)" "(HT) Haiti" "(HU) Hungary" "(ID) Indonesia" "(IE) Ireland" "(IL) Israel" "(IM) Isle of Man" "(IN) India" "(IO) British Indian Ocean Territory" "(IS) Iceland" "(IT) Italy" "(JE) Jersey" "(JM) Jamaica" "(JO) Jordan" "(JP) Japan" "(KE) Kenya" "(KG) Kyrgyzstan" "(KH) Cambodia" "(KI) Kiribati" "(KM) Comoros" "(KN) Saint Kitts and Nevis" "(KR) Korea (South)" "(KW) Kuwait" "(KY) Cayman Islands" "(KZ) Kazakhstan" "(LA) Laos" "(LC) Saint Lucia" "(LI) Liechtenstein" "(LK) Sri Lanka" "(LS) Lesotho" "(LT) Lithuania" "(LU) Luxembourg" "(LV) Latvia" "(LY) Libya" "(MA) Morocco" "(MC) Monaco" "(MD) Moldova" "(ME) Montenegro" "(MG) Madagascar" "(MH) Marshall Islands" "(MK) Macedonia" "(ML) Mali" "(MM) Myanmar" "(MN) Mongolia" "(MO) Macau" "(MP) Northern Mariana Islands" "(MQ) Martinique" "(MR) Mauritania" "(MS) Montserrat" "(MT) Malta" "(MU) Mauritius" "(MV) Maldives" "(MW) Malawi" "(MX) Mexico" "(MY) Malaysia" "(MZ) Mozambique" "(NA) Namibia" "(NC) New Caledonia" "(NE) Niger" "(NF) Norfolk Island" "(NG) Nigeria" "(NI) Nicaragua" "(NL) Netherlands" "(NO) Norway" "(NP) Nepal" "(NR) Nauru" "(NT) Neutral Zone" "(NU) Niue" "(NZ) New Zealand (Aotearoa)" "(OM) Oman" "(PA) Panama" "(PE) Peru" "(PF) French Polynesia" "(PG) Papua New Guinea" "(PH) Philippines" "(PK) Pakistan" "(PL) Poland" "(PM) St. Pierre and Miquelon" "(PN) Pitcairn" "(PR) Puerto Rico" "(PS) Palestinian Territory" "(PT) Portugal" "(PW) Palau" "(PY) Paraguay" "(QA) Qatar" "(RE) Reunion" "(RO) Romania" "(RS) Serbia" "(RU) Russian Federation" "(RW) Rwanda" "(SA) Saudi Arabia" "(SB) Solomon Islands" "(SC) Seychelles" "(SE) Sweden" "(SG) Singapore" "(SH) St. Helena" "(SI) Slovenia" "(SJ) Svalbard and Jan Mayen Islands" "(SK) Slovak Republic" "(SL) Sierra Leone" "(SM) San Marino" "(SN) Senegal" "(SR) Suriname" "(ST) Sao Tome and Principe" "(SU) USSR (former)" "(SV) El Salvador" "(SZ) Swaziland" "(TC) Turks and Caicos Islands" "(TD) Chad" "(TF) French Southern Territories" "(TG) Togo" "(TH) Thailand" "(TJ) Tajikistan" "(TK) Tokelau" "(TM) Turkmenistan" "(TN) Tunisia" "(TO) Tonga" "(TP) East Timor" "(TR) Turkey" "(TT) Trinidad and Tobago" "(TV) Tuvalu" "(TW) Taiwan" "(TZ) Tanzania" "(UA) Ukraine" "(UG) Uganda" "(UM) US Minor Outlying Islands" "(US) United States" "(UY) Uruguay" "(UZ) Uzbekistan" "(VA) Vatican City State (Holy See)" "(VC) Saint Vincent and the Grenadines" "(VE) Venezuela" "(VG) Virgin Islands (British)" "(VI) Virgin Islands (U.S.)" "(VN) Viet Nam" "(VU) Vanuatu" "(WF) Wallis and Futuna Islands" "(WS) Samoa" "(YE) Yemen" "(YT) Mayotte" "(ZA) South Africa" "(ZM) Zambia" "(COM) US Commercial" "(EDU) US Educational" "(GOV) US Government" "(INT) International" "(MIL) US Military" "(NET) Network" "(ORG) Non-Profit Organization" "(ARPA) Old style Arpanet")
declare COUNTRY_ABBREV=("US" "CA" "AX" "AD" "AE" "AF" "AG" "AI" "AL" "AM" "AN" "AO" "AQ" "AR" "AS" "AT" "AU" "AW" "AZ" "BA" "BB" "BD" "BE" "BF" "BG" "BH" "BI" "BJ" "BM" "BN" "BO" "BR" "BS" "BT" "BV" "BW" "BZ" "CA" "CC" "CF" "CH" "CI" "CK" "CL" "CM" "CN" "CO" "CR" "CS" "CV" "CX" "CY" "CZ" "DE" "DJ" "DK" "DM" "DO" "DZ" "EC" "EE" "EG" "EH" "ER" "ES" "ET" "FI" "FJ" "FK" "FM" "FO" "FR" "FX" "GA" "GB" "GD" "GE" "GF" "GG" "GH" "GI" "GL" "GM" "GN" "GP" "GQ" "GR" "GS" "GT" "GU" "GW" "GY" "HK" "HM" "HN" "HR" "HT" "HU" "ID" "IE" "IL" "IM" "IN" "IO" "IS" "IT" "JE" "JM" "JO" "JP" "KE" "KG" "KH" "KI" "KM" "KN" "KR" "KW" "KY" "KZ" "LA" "LC" "LI" "LK" "LS" "LT" "LU" "LV" "LY" "MA" "MC" "MD" "ME" "MG" "MH" "MK" "ML" "MM" "MN" "MO" "MP" "MQ" "MR" "MS" "MT" "MU" "MV" "MW" "MX" "MY" "MZ" "NA" "NC" "NE" "NF" "NG" "NI" "NL" "NO" "NP" "NR" "NT" "NU" "NZ" "OM" "PA" "PE" "PF" "PG" "PH" "PK" "PL" "PM" "PN" "PR" "PS" "PT" "PW" "PY" "QA" "RE" "RO" "RS" "RU" "RW" "SA" "SB" "SC" "SE" "SG" "SH" "SI" "SJ" "SK" "SL" "SM" "SN" "SR" "ST" "SU" "SV" "SZ" "TC" "TD" "TF" "TG" "TH" "TJ" "TK" "TM" "TN" "TO" "TP" "TR" "TT" "TV" "TW" "TZ" "UA" "UG" "UM" "US" "UY" "UZ" "VA" "VC" "VE" "VG" "VI" "VN" "VU" "WF" "WS" "YE" "YT" "ZA" "ZM" "COM" "EDU" "GOV" "INT" "MIL" "NET" "ORG" "ARPA")

MENU_SELECTION_POSITION=-1
MENU_SELECTION=''

maskAllChars()
{
  echo $1 | sed -e "s/./*/g"
}

# this script assumes the presence of certain files in the same directory as the executable
# Ensure that the $CWD is where the executable is
cd "${SCRIPT_DIR}"

function deploy_on_azure () {

  echo "Let's start with some Azure basics:"
  read -p "Azure username: " AZURE_USERNAME
  read -s -p "Azure password: " AZURE_PASSWORD
  maskAllChars $AZURE_PASSWORD 1

  # Log into Azure & set environment info
  az login -u $AZURE_USERNAME -p $AZURE_PASSWORD
  echo
  read -p "Deployment name: " NAME
  echo "Select a Region:"
#  echo "For a list of regions, run:"
#  echo "az account list-locations | jq -r '.[].name'"
#  read -p "Azure region: " AZ_REG

  REGION_OPTIONS=( $( az account list-locations | jq -r '.[].name' ) )
  createMenu "${#REGION_OPTIONS[@]}" "${REGION_OPTIONS[@]}"
  AZ_REG=$MENU_SELECTION
  echo "Selected: "$AZ_REG

  read -p "Remote access app name: " APP_NAME
  echo "Let's create a key for the Application Gateway:"
  read -s -p "Pick a private key password: " KEY_PASSWORD
  echo
#  read -p "Enter your Country: " COUNTRY

  echo "Select your Country (full name): "
  createMenu "${#COUNTRY_ABBREV[@]}" "${COUNTRY_ABBREV[@]}"
  COUNTRY=$MENU_SELECTION
  echo "Selected: "$COUNTRY

  sleep 1
  echo "Select your State (full name): "
  createMenu "${#STATES_OPTIONS[@]}" "${STATES_OPTIONS[@]}"
  STATE=$MENU_SELECTION
  echo "Selected: "$STATE

#  read -p "Enter your State (full name): " STATE
  read -p "Enter your City: " CITY
  read -p "Enter your Company Name: " ORGANIZATION
  read -p "Enter your Department: "  DEPARTMENT
  read -p "Enter your Domain Name: " DOMAIN_NAME
  echo "Here we go!"

  cd $DEPLOY_DIR
  pwd
  APP_ACCESS="http://$APP_NAME"


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
  cd -
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
