# Google Cloud CDN for Private GCS Bucket - Automation Script

## Overview
This project provides a Bash script to automate the setup of a secure, private [Google Cloud Storage (GCS)](https://cloud.google.com/storage) bucket behind a global [Google Cloud HTTP(S) Load Balancer](https://cloud.google.com/load-balancing/docs/https) with [CDN](https://cloud.google.com/cdn) enabled. This solution is ideal for serving static content (such as images, videos, or web assets) securely and efficiently at global scale.

By using this script, you can:
- Keep your GCS bucket private (not publicly accessible)
- Serve content globally with low latency via Google's CDN
- Automate a complex, multi-step GCP setup into a single, repeatable process

---

## Features

- **Private GCS Bucket:** Your data is not exposed to the public internet.
- **Service Account with HMAC Keys:** Enables signed requests for secure access.
- **Network Endpoint Group (NEG):** Points the load balancer to your GCS bucket.
- **Global HTTP(S) Load Balancer:** Handles traffic, enables CDN, and enforces security.
- **Automated Setup:** All resources are created and configured by a single script.
- **Origin Authentication:** Uses AWS V4 signing to authenticate requests from the load balancer to the bucket.

---

## Architecture

```
+-------------------+         +-------------------+         +-------------------+
|                   |  HTTPS  |                   |  HTTPS  |                   |
|     Client        +-------->+  Google Cloud     +-------->+  GCS Bucket       |
|   (Browser/CDN)   |         |  Load Balancer    |         |  (Private)        |
|                   |         |  (with CDN)       |         |                   |
+-------------------+         +-------------------+         +-------------------+
                                    |   ^   |   |
                                    |   |   |   |
                                    |   |   |   |
                                    |   |   |   |
                                    v   |   v   |
                                NEG (FQDN)   Service Account
                                             (HMAC keys for
                                              signed requests)
```

**Flow:**
1. The client (browser or CDN edge) sends an HTTPS request to the load balancer.
2. The load balancer, with CDN enabled, routes the request to a NEG that points to the GCS bucket's FQDN.
3. The load balancer uses a service account with HMAC keys to sign requests (AWS V4) to the private bucket.
4. The bucket serves the content if the request is valid.

---

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`) and [`gsutil`](https://cloud.google.com/storage/docs/gsutil_install) installed and authenticated.
- Permissions to create buckets, service accounts, and networking resources in your GCP project.
- Billing enabled on your GCP project.
- Bash shell (Linux, macOS, or Windows with WSL/Git Bash).

---

## Setup & Usage

### 1. Clone or Download

Download this repository or copy the script to your local machine.

### 2. Configure Variables

Open `script.sh` and set the following variables at the top:

```bash
PROJECT_ID="your-gcp-project-id"
BUCKET_NAME="your-unique-bucket-name"
REGION="your-region"  # e.g., us-central1
SERVICE_ACCOUNT_NAME="your-service-account-name"
SERVICE_ACCOUNT_DISPLAY_NAME="Service Account for GCS CDN"
NEG_NAME="your-neg-name"
LOAD_BALANCER_NAME="your-lb-name"
FRONTEND_IP_NAME="your-frontend-ip-name"
BACKEND_SERVICE_NAME="your-backend-service-name"
CACHE_TTL="3600"  # (Optional) Cache TTL in seconds
```

**Tip:** Bucket names must be globally unique.

### 3. Run the Script

Make the script executable and run it:

```bash
chmod +x script.sh
./script.sh
```

The script will:
- Create a private GCS bucket and upload a test file
- Create a service account and HMAC keys
- Grant the service account access to the bucket
- Set up a NEG pointing to the bucket
- Reserve a global IP and configure the load balancer with CDN
- Enable signed origin authentication

### 4. Retrieve Output

At the end, the script will display:
- The frontend IP address (use this to access your content)
- The HMAC access and secret keys (store these securely)

---

## Variables to Set

| Variable                   | Description                                 | Example                |
|----------------------------|---------------------------------------------|------------------------|
| `PROJECT_ID`               | Your GCP project ID                         | my-gcp-project         |
| `BUCKET_NAME`              | Name for your GCS bucket (must be unique)   | my-static-bucket       |
| `REGION`                   | GCP region                                  | us-central1            |
| `SERVICE_ACCOUNT_NAME`     | Service account name                        | gcs-cdn-svc            |
| `SERVICE_ACCOUNT_DISPLAY_NAME` | Service account display name             | GCS CDN Service Account|
| `NEG_NAME`                 | Network Endpoint Group name                 | gcs-cdn-neg            |
| `LOAD_BALANCER_NAME`       | Load balancer name                          | gcs-cdn-lb             |
| `FRONTEND_IP_NAME`         | Reserved frontend IP name                   | gcs-cdn-ip             |
| `BACKEND_SERVICE_NAME`     | Backend service name                        | gcs-cdn-backend        |
| `CACHE_TTL`                | (Optional) Cache TTL in seconds             | 3600                   |

---

## Security Notes

- **Private Bucket:** The GCS bucket is not public; only the load balancer can access it using signed requests.
- **HMAC Keys:** These are sensitive credentials. Store them securely and rotate them regularly.
- **Principle of Least Privilege:** The service account is granted only the permissions it needs.
- **Cleanup:** Remember to delete resources when no longer needed to avoid unnecessary charges.

---

## Troubleshooting

- **Permission Errors:** Ensure your user/service account has the necessary IAM roles (Storage Admin, Compute Admin, etc.).
- **Bucket Name Already Exists:** GCS bucket names are global. Choose a unique name.
- **Resource Quotas:** Check your GCP quotas if resource creation fails.
- **Script Fails Midway:** Rerun the script or manually clean up partially created resources.

---

## References & Further Reading

- [Google Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [Google Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)
- [Google Cloud CDN](https://cloud.google.com/cdn/docs)
- [Origin Authentication for Google Cloud CDN](https://cloud.google.com/cdn/docs/private-origins)

---

## License

MIT

---

If you have questions or suggestions, feel free to open an issue or connect with me on [LinkedIn](https://www.linkedin.com/). 
