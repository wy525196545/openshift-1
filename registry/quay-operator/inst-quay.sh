# Set environment variables
export CHANNEL_NAME="stable-3.13"
export STORAGE_CLASS_NAME="gp2-csi"
export STORAGE_SIZE="50Gi"

#!/bin/bash

# Function to print a task with uniform length
PRINT_TASK() {
    max_length=110  # Adjust this to your desired maximum length
    task_title="$1"
    title_length=${#task_title}
    stars=$((max_length - title_length))

    echo "$task_title$(printf '*%.0s' $(seq 1 $stars))"
}
# ====================================================

# Function to check command success and display appropriate message
run_command() {
    if [ $? -eq 0 ]; then
        echo "ok: $1"
    else
        echo "failed: $1"
    fi
}
# ====================================================

# Print task title
PRINT_TASK "[TASK: Install Minio Tool]"

# Check if mc is already installed and operational
if mc --version &> /dev/null; then
    run_command "[MC tool already installed, skipping installation]"
else
    # Download the MC tool
    curl -OL https://dl.min.io/client/mc/release/linux-amd64/mc &> /dev/null
    run_command "[Downloaded MC tool]"

    # Remove the old version (if it exists)
    rm -f /usr/local/bin/mc &> /dev/null

    # Move the new version to /usr/local/bin
    mv mc /usr/local/bin/ &> /dev/null
    run_command "[Installed MC tool to /usr/local/bin/]"

    # Set execute permissions for the tool
    chmod +x /usr/local/bin/mc &> /dev/null
    run_command "[Set execute permissions for MC tool]"

    # Verify the installation
    if mc --version &> /dev/null; then
        run_command "[MC tool installation complete]"
    else
        run_command "[Failed to install MC tool, proceeding without it]"
    fi
fi

echo 

# Print task title
PRINT_TASK "[TASK: Deploying Minio object]"

# Deploy Minio with the specified YAML template
export NAMESPACE="minio"

curl -s https://raw.githubusercontent.com/pancongliang/openshift/main/storage/minio/deploy-minio-with-persistent-volume.yaml | envsubst | oc apply -f - &> /dev/null
run_command "[Applied Minio object]"

# Wait for Minio pods to be in 'Running' state
while true; do
    # Check the status of pods
    if oc get pods -n "$NAMESPACE" --no-headers | awk '{print $3}' | grep -v "Running" &> /dev/null; then
        echo "info: [Waiting for pods to be in 'Running' state...]"
        sleep 20
    else
        echo "ok: [Minio pods are in 'Running' state]"
        break
    fi
done

# Get Minio route URL
export BUCKET_HOST=$(oc get route minio -n ${NAMESPACE} -o jsonpath='{.spec.host}')
run_command "[Retrieved Minio route host: $BUCKET_HOST]"

sleep 3

# Set Minio client alias
mc --no-color alias set my-minio http://${BUCKET_HOST} minioadmin minioadmin &> /dev/null
run_command "[Configured Minio client alias]"

# Create buckets for Loki, Quay, OADP, and MTC
for BUCKET_NAME in "quay-bucket"; do
    mc --no-color mb my-minio/$BUCKET_NAME &> /dev/null
    run_command "[Created bucket $BUCKET_NAME]"
done

echo 

# Print task title
PRINT_TASK "[TASK: Deploying Quay Operator]"

cat << EOF | oc apply -f - &> /dev/null
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: quay-operator
  namespace: openshift-operators
spec:
  channel: ${CHANNEL_NAME}
  installPlanApproval: Automatic
  name: quay-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
run_command "[Installing Quay Operator...]"

sleep 60

oc new-project quay-enterprise &> /dev/null
run_command "[Create a quay-enterprise namespac]"

export BUCKET_HOST=$(oc get route minio -n minio -o jsonpath='{.spec.host}')
export ACCESS_KEY_ID="minioadmin"
export ACCESS_KEY_SECRET="minioadmin"
export BUCKET_NAME="quay-bucket"

cat << EOF > config.yaml
DISTRIBUTED_STORAGE_CONFIG:
  default:
    - RadosGWStorage
    - access_key: ${ACCESS_KEY_ID}
      secret_key: ${ACCESS_KEY_SECRET}
      bucket_name: ${BUCKET_NAME}
      hostname: ${BUCKET_HOST}
      is_secure: false
      port: 80
      storage_path: /
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - default
SUPER_USERS:
    - quayadmin
EOF

oc create secret generic quay-config --from-file=config.yaml -n quay-enterprise &> /dev/null
run_command "[Create a secret containing quay-config]"

rm -rf config.yaml  &> /dev/null

cat << EOF | oc apply -f - &> /dev/null
apiVersion: quay.redhat.com/v1
kind: QuayRegistry
metadata:
  name: example-registry
  namespace: quay-enterprise
spec:
  configBundleSecret: quay-config
  components:
    - kind: objectstorage
      managed: false
    - kind: horizontalpodautoscaler
      managed: false
    - kind: quay
      managed: true
      overrides:
        replicas: 1
    - kind: clair
      managed: true
      overrides:
        replicas: 1
    - kind: mirror
      managed: true
      overrides:
        replicas: 1
EOF
run_command "[Create a QuayRegistry]"

# Print task title
PRINT_TASK "[TASK: Install oc-mirror tool]"

# Check if oc-mirror is already installed and operational
if oc-mirror -h &> /dev/null; then
    run_command "[The oc-mirror tool already installed, skipping installation]"
else
    # Download the oc-mirror tool
    curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/oc-mirror.tar.gz &> /dev/null
    run_command "[Downloaded oc-mirror tool]"

    # Remove the old version (if it exists)
    rm -f /usr/local/bin/oc-mirror &> /dev/null

    tar -xvf oc-mirror.tar.gz &> /dev/null

    # Set execute permissions for the tool
    chmod +x oc-mirror &> /dev/null
    run_command "[Set execute permissions for oc-mirror tool]"

    # Move the new version to /usr/local/bin
    mv oc-mirror /usr/local/bin/ &> /dev/null
    run_command "[Installed oc-mirror tool to /usr/local/bin/]"

    # Verify the installation
    if oc-mirror -h &> /dev/null; then
        run_command "[oc-mirror tool installation complete]"
    else
        run_command "[Failed to install oc-mirror tool, proceeding without it]"
    fi
fi

echo 

# Print task title
PRINT_TASK "[TASK: Configuring additional trust stores for image registry access]"

# Export the router-ca certificate
oc extract secrets/router-ca --keys tls.crt -n openshift-ingress-operator &> /dev/null 
run_command "[Export the router-ca certificate]"

# Create a configmap containing the CA certificate
export QUAY_HOST=$(oc get route example-registry-quay -n quay-enterprise --template='{{.spec.host}}')
oc create configmap registry-config --from-file=$QUAY_HOST=tls.crt -n openshift-config &> /dev/null
run_command "[Create a configmap containing the CA certificate]"

# Additional trusted CA
oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"registry-config"}}}' --type=merge &> /dev/null
run_command "[Additional trusted CA]"

rm -rf tls.crt &> /dev/null


echo 

# Print task title
PRINT_TASK "[TASK: Update pull-secret]"

# Export pull-secret
oc get secret/pull-secret -n openshift-config --output="jsonpath={.data.\.dockerconfigjson}" | base64 -d > pull-secret
run_command "[Export pull-secret]"

# Update pull-secret file
export AUTHFILE="pull-secret"
export REGISTRY=$(oc get route example-registry-quay -n quay-enterprise --template='{{.spec.host}}')
export USERNAME="quayadmin"
export PASSWORD="password"

# Base64 encode the username:password
AUTH=$(echo -n "$USERNAME:$PASSWORD" | base64)

if [ -f "$AUTHFILE" ]; then
  jq --arg registry "$REGISTRY" \
     --arg auth "$AUTH" \
     '.auths[$registry] = {auth: $auth}' \
     "$AUTHFILE" > tmp-authfile && mv tmp-authfile "$AUTHFILE"
else
  cat <<EOF > $AUTHFILE
{
    "auths": {
        "$REGISTRY": {
            "auth": "$AUTH"
        }
    }
}
EOF
fi
echo "info: [Authentication information for $REGISTRY added to $AUTHFILE]"

# Update pull-secret
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=pull-secret
run_command "[Update pull-secret]"

rm -rf pull-secret &> /dev/null

while true; do
    operator_status=$(/usr/local/bin/oc --kubeconfig=${IGNITION_PATH}/auth/kubeconfig get co --no-headers | awk '{print $3, $4, $5}')
    if echo "$operator_status" | grep -q -v "True False False"; then
        echo "info: [all cluster operators have not reached the expected status, Waiting...]"
        sleep 60  
    else
        echo "ok: [all cluster operators have reached the expected state]"
        break
    fi
done


echo "info: [Red Hat Quay Operator has been deployed]"
echo "info: [Wait for the pod in the quay-enterprise namespace to be in the running state]"
echo "note: [You need to create a user in the Quay console with an ID of <quayadmin> and a PW of <password>]"
