#!/bin/bash

# Variables
PROJECT_ID="YOUR_PROJECT_ID"
BUCKET_NAME="YOUR_BUCKET_NAME"  # Replace with your desired bucket name
REGION="YOUR_REGION"
SERVICE_ACCOUNT_NAME="YOUR_SERVICE_ACCOUNT_NAME"
SERVICE_ACCOUNT_DISPLAY_NAME="YOUR_SERVICE_ACCOUNT_DISPLAY_NAME"
NEG_NAME="YOUR_NEG_NAME"
LOAD_BALANCER_NAME="YOUR_LOAD_BALANCER_NAME"
FRONTEND_IP_NAME="YOUR_FRONTEND_IP_NAME"
BACKEND_SERVICE_NAME="YOUR_BACKEND_SERVICE_NAME"
CACHE_TTL="3600"  # Cache TTL in seconds (1 hour)

# Set the project
gcloud config set project $PROJECT_ID

# Step 1: Create a private GCS bucket
echo "Creating private GCS bucket..."
gsutil mb -l $REGION gs://$BUCKET_NAME
echo "Uploading a test file to the bucket..."
echo "This is a test file." > test.txt
gsutil cp test.txt gs://$BUCKET_NAME/test.txt
rm test.txt

# Step 2: Create a service account
echo "Creating service account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="$SERVICE_ACCOUNT_DISPLAY_NAME" \
    --project=$PROJECT_ID

SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Step 3: Grant the service account access to the bucket
echo "Granting service account access to the bucket..."
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:roles/storage.admin gs://$BUCKET_NAME

# Step 4: Create HMAC keys for the service account
echo "Creating HMAC keys for the service account..."
HMAC_KEY_OUTPUT=$(gcloud storage hmac create $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID)
ACCESS_KEY=$(echo "$HMAC_KEY_OUTPUT" | grep "accessId" | awk '{print $2}')
SECRET_KEY=$(echo "$HMAC_KEY_OUTPUT" | grep "secret" | awk '{print $2}')

echo "HMAC Access Key: $ACCESS_KEY"
echo "HMAC Secret Key: $SECRET_KEY"

# Step 5: Create an Internet NEG with FQDN endpoint
echo "Creating Internet NEG..."
GCS_FQDN="$BUCKET_NAME.storage.googleapis.com"
gcloud compute network-endpoint-groups create $NEG_NAME \
    --network-endpoint-type="internet-fqdn-port" \
    --global \
    --project=$PROJECT_ID

# Add GCS FQDN as an endpoint
echo "Adding GCS FQDN as an endpoint to the NEG..."
gcloud compute network-endpoint-groups update $NEG_NAME \
    --add-endpoint="fqdn=$GCS_FQDN,port=443" \
    --global \
    --project=$PROJECT_ID

# Verify the NEG and endpoint
echo "Listing NEGs..."
gcloud compute network-endpoint-groups list --global

echo "Listing endpoints in the NEG..."
gcloud compute network-endpoint-groups list-network-endpoints $NEG_NAME --global

# Step 6: Create an HTTP(S) Load Balancer
echo "Creating HTTP(S) Load Balancer..."

# Step 6.1: Reserve a frontend IP address
echo "Reserving frontend IP address..."
gcloud compute addresses create $FRONTEND_IP_NAME \
    --global \
    --project=$PROJECT_ID

FRONTEND_IP=$(gcloud compute addresses describe $FRONTEND_IP_NAME --global --format="value(address)")

# Step 6.2: Create backend service
echo "Creating backend service..."
gcloud compute backend-services create $BACKEND_SERVICE_NAME \
    --protocol=HTTPS \
    --global \
    --enable-cdn \
    --cache-mode=force-cache-all \
    --default-ttl=$CACHE_TTL \
    --custom-request-header="host: [$BUCKET_NAME.storage.googleapis.com]" \
    --project=$PROJECT_ID --global


# Attach NEG to backend service
gcloud compute backend-services add-backend $BACKEND_SERVICE_NAME \
    --network-endpoint-group=$NEG_NAME \
    --global \
    --project=$PROJECT_ID 

# Step 6.3: Create URL map
echo "Creating URL map..."
gcloud compute url-maps create $LOAD_BALANCER_NAME \
    --default-service=$BACKEND_SERVICE_NAME \
    --project=$PROJECT_ID

# Step 6.4: Create target HTTP proxy
echo "Creating target HTTP proxy..."
gcloud compute target-http-proxies create $LOAD_BALANCER_NAME-http-proxy \
    --url-map=$LOAD_BALANCER_NAME \
    --project=$PROJECT_ID

# Step 6.5: Create global forwarding rule
echo "Creating global forwarding rule..."
gcloud compute forwarding-rules create $LOAD_BALANCER_NAME-forwarding-rule \
    --target-http-proxy=$LOAD_BALANCER_NAME-http-proxy \
    --ports=80 \
    --address=$FRONTEND_IP \
    --global \
    --project=$PROJECT_ID

# Step 7: Update backend service for private origin authentication
echo "Updating backend service for private origin authentication..."

# Create YAML configuration for security settings
cat <<EOF > cdn-private-origin.yaml
securitySettings:
  awsV4Authentication:
    accessKeyId: $ACCESS_KEY
    accessKey: $SECRET_KEY
    originRegion: $REGION
EOF

# Import the YAML configuration into the backend service
gcloud compute backend-services import $BACKEND_SERVICE_NAME \
    --source=cdn-private-origin.yaml \
    --global \
    --project=$PROJECT_ID

echo "Adding customer request header..."
gcloud compute backend-services update $BACKEND_SERVICE_NAME \
    --custom-request-header="host: $BUCKET_NAME.storage.googleapis.com" --global 

# Clean up temporary YAML file
rm cdn-private-origin.yaml

echo "Setup complete!"
echo "Frontend IP: $FRONTEND_IP"
echo "HMAC Access Key: $ACCESS_KEY"
echo "HMAC Secret Key: $SECRET_KEY"




