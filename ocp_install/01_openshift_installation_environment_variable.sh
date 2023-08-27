#!/bin/bash
###### Variable needs to be change ######

#######  OpenShift version ####### 
export OCP_RELEASE="4.10.20"

#######  OpenShift install-config ####### 
export CLUSTER_NAME="ocp4"
export BASE_DOMAIN="example.com"
export ID_RSA_PUB_FILE="/root/.ssh/id_rsa.pub"
export NETWORK_TYPE="OVNKubernetes"              # OVNKubernetes or OpenShiftSDN
export POD_CIDR="10.128.0.0/14"                  # Generally use the default value
export HOST_PREFIX="23"                          # Generally use the default value
export SERVICE_CIDR="172.30.0.0/16"              # Generally use the default value
export SERVICE_CIDR="172.30.0.0/16"


#######  OpenShift infrastructure network ####### 
export GATEWAY_IP="10.74.255.254"
export NETMASK="21"
export DNS_FORWARDER_IP="10.75.5.25"

#######  OpenShift Node Hostname/IP variable ####### 
export BASTION_HOSTNAME="bastion"
export BOOTSTRAP_HOSTNAME="bootstrap"
export MASTER01_HOSTNAME="master01"
export MASTER02_HOSTNAME="master02"
export MASTER03_HOSTNAME="master03"
export WORKER01_HOSTNAME="worker01"
export WORKER02_HOSTNAME="worker02"
export BASTION_IP="10.74.251.171"
export MASTER01_IP="10.74.251.61"
export MASTER02_IP="10.74.254.155"
export MASTER03_IP="10.74.253.133"
export WORKER01_IP="10.74.251.58"
export WORKER02_IP="10.74.253.49"
export BOOTSTRAP_IP="10.74.255.118"

#######  OpenShift Node disk/interface ####### 
export COREOS_INSTALL_DEV="/dev/sda"
export NET_IF_NAME="'Wired connection 1'"    # nmcli con show

#######  Registry and mirror variable ####### 
export REGISTRY_HOSTNAME="docker.registry"
export REGISTRY_ID="admin"
export REGISTRY_PW="redhat"
export PULL_SECRET="/root/pull-secret"                # Download https://console.redhat.com/openshift/install/metal/installer-provisioned
export REGISTRY_CERT_PATH="/etc/certs"
export REGISTRY_INSTALL_PATH="/opt/registry"          # Store registry auth/certs/data

#######  NFS directory is used to create image-registry pod pv ####### 
export NFS_PATH="/nfs"
export IMAGE_REGISTRY_PV="image-registry"

####### Httpd and ocp ignition dir #######
export HTTPD_PATH="/var/www/html/materials"          #         
export IGNITION_PATH="${HTTPD_PATH}/pre"

#######################################################
####### No need to change #######

####### Create the directory if it doesn't exist #######
mkdir -p ${REGISTRY_CERT_PATH}
mkdir -p ${REGISTRY_INSTALL_PATH}
mkdir -p ${NFS_PATH}
mkdir -p ${HTTPD_PATH}
mkdir -p ${IGNITION_PATH}

####### Download ocp image #######
export LOCAL_REPOSITORY="ocp4/openshift4"
export PRODUCT_REPO="openshift-release-dev" 
export RELEASE_NAME="ocp-release"
export ARCHITECTURE="x86_64"

####### Function to generate duplicate IP address #######
export DNS_IP="$BASTION_IP"
export REGISTRY_IP="$BASTION_IP"
export API_IP="$BASTION_IP"
export API_INT_IP="$BASTION_IP"
export APPS_IP="$BASTION_IP"

sleep 1

####### Function to generate reversed DNS, Generate reversed DNS for each IP and store as variables #######
generate_reverse_ip() {
  local ip="$1"
  reversed_dns=$(echo "$ip" | awk -F'.' '{print $4"."$3}')
  echo "$reversed_dns"
}

export BASTION_REVERSE_IP=$(generate_reverse_ip "$BASTION_IP")
export REGISTRY_REVERSE_IP=$(generate_reverse_ip "$REGISTRY_IP")
export MASTER01_REVERSE_IP=$(generate_reverse_ip "$MASTER01_IP")
export MASTER02_REVERSE_IP=$(generate_reverse_ip "$MASTER02_IP")
export MASTER03_REVERSE_IP=$(generate_reverse_ip "$MASTER03_IP")
export WORKER01_REVERSE_IP=$(generate_reverse_ip "$WORKER01_IP")
export WORKER02_REVERSE_IP=$(generate_reverse_ip "$WORKER02_IP")
export BOOTSTRAP_REVERSE_IP=$(generate_reverse_ip "$BOOTSTRAP_IP")
export API_REVERSE_IP=$(generate_reverse_ip "$API_IP")
export API_INT_REVERSE_IP=$(generate_reverse_ip "$API_INT_IP")

####### Function to generate reversed_ip_par/zone name #######
export IP_PART=$(echo "$BASTION_IP" | cut -d. -f1-2)
export REVERSED_IP_PART=$(echo "$IP_PART" | awk -F'.' '{print $2"."$1}')
export REVERSE_ZONE="$REVERSED_IP_PART.in-addr.arpa"
export REVERSE_ZONE_FILE_NAME="$REVERSED_IP_PART.zone"
export FORWARD_ZONE="$BASE_DOMAIN"
export FORWARD_ZONE_FILE_NAME="$BASE_DOMAIN.zone"

#######################################################

echo ====== Check all variables ======
# Define variables
missing_variables=()

# Define a function to check if a variable is set
check_variable() {
    if [ -z "${!1}" ]; then
        missing_variables+=("$1")
    fi
}

# Check all variables that need validation
check_all_variables() {
    check_variable "OCP_RELEASE"
    check_variable "CLUSTER_NAME"
    check_variable "BASE_DOMAIN"
    check_variable "ID_RSA_PUB_FILE"
    check_variable "NETWORK_TYPE"
    check_variable "POD_CIDR"
    check_variable "HOST_PREFIX"
    check_variable "SERVICE_CIDR"
    check_variable "GATEWAY_IP"
    check_variable "NETMASK"
    check_variable "DNS_FORWARDER_IP"
    check_variable "BASTION_HOSTNAME"
    check_variable "BOOTSTRAP_HOSTNAME"
    check_variable "MASTER01_HOSTNAME"
    check_variable "MASTER02_HOSTNAME"
    check_variable "MASTER03_HOSTNAME"
    check_variable "WORKER01_HOSTNAME"
    check_variable "WORKER02_HOSTNAME"
    check_variable "BASTION_IP"
    check_variable "MASTER01_IP"
    check_variable "MASTER02_IP"
    check_variable "MASTER03_IP"
    check_variable "WORKER01_IP"
    check_variable "WORKER02_IP"
    check_variable "BOOTSTRAP_IP"
    check_variable "COREOS_INSTALL_DEV"
    check_variable "NET_IF_NAME"
    check_variable "REGISTRY_HOSTNAME"
    check_variable "REGISTRY_ID"
    check_variable "REGISTRY_PW"
    check_variable "PULL_SECRET"
    check_variable "REGISTRY_CERT_PATH"  
    check_variable "REGISTRY_INSTALL_PATH"
    check_variable "NFS_PATH"
    check_variable "IMAGE_REGISTRY_PV"
    check_variable "DNS_IP"
    check_variable "REGISTRY_IP"
    check_variable "API_IP"
    check_variable "API_INT_IP"
    check_variable "APPS_IP"
    check_variable "BASTION_REVERSE_IP"
    check_variable "REGISTRY_REVERSE_IP"
    check_variable "MASTER01_REVERSE_IP"
    check_variable "MASTER02_REVERSE_IP"
    check_variable "MASTER03_REVERSE_IP"
    check_variable "WORKER01_REVERSE_IP"
    check_variable "WORKER02_REVERSE_IP"
    check_variable "BOOTSTRAP_REVERSE_IP"
    check_variable "API_REVERSE_IP"
    check_variable "API_INT_REVERSE_IP"
    check_variable "IP_PART"
    check_variable "REVERSED_IP_PART"
    check_variable "REVERSE_ZONE"
    check_variable "REVERSE_ZONE_FILE_NAME"
    check_variable "FORWARD_ZONE"
    check_variable "FORWARD_ZONE_FILE_NAME"
    check_variable "LOCAL_REPOSITORY"
    check_variable "PRODUCT_REPO"
    check_variable "RELEASE_NAME"
    check_variable "ARCHITECTURE"
    check_variable "HTTPD_PATH"
    check_variable "IGNITION_PATH"
    # If all variables are set, display a success message
    echo "All variables are set."    
}

# Call the function to check all variables
check_all_variables

# Display missing variables, if any
if [ ${#missing_variables[@]} -gt 0 ]; then
    echo "Missing or unset variables:"
    for var in "${missing_variables[@]}"; do
        echo "- $var"
    done
else
    echo "All variables are set."
fi

#######################################################
