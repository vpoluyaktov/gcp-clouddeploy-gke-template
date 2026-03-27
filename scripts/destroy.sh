#!/usr/bin/env bash
#
# destroy.sh — Tear down all cloud infrastructure created by this repository.
#
# Usage:
#   ./scripts/destroy.sh <environment>
#
# Arguments:
#   environment   "prod" or "stage"
#
# Prerequisites:
#   - gcloud CLI authenticated with sufficient permissions
#   - terraform CLI installed
#   - The Terraform backend bucket must be accessible
#
# What this script destroys:
#   1. Kubernetes workloads (deployment, service, service-account, ingress, managed-certificate, frontend-config) via kubectl
#   2. Cloud Deploy delivery pipeline, target, and release artifacts
#   3. All Terraform-managed resources via terraform destroy:
#      - GKE Autopilot cluster
#      - Artifact Registry repository (and all images)
#      - Firestore database and seed document
#      - Cloud Deploy pipeline, target, execution SA, and IAM bindings
#      - Runtime SA, IAM bindings, and Workload Identity binding
#      - Global static IP (google_compute_global_address)
#      - DNS A record (cross-project)
#      - GCP API enablements
#   4. Cloud Deploy artifacts in GCS bucket
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- Validate arguments ----------
if [[ $# -ne 1 ]] || [[ "$1" != "prod" && "$1" != "stage" ]]; then
  echo "Usage: $0 <prod|stage>"
  exit 1
fi

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

# ---------- Load environment config ----------
if [[ "$ENV" == "prod" ]]; then
  VAR_FILE="${TF_DIR}/prod/prod.tfvars"
  BACKEND_FILE="${TF_DIR}/prod/backend.tf"
else
  VAR_FILE="${TF_DIR}/stage/stage.tfvars"
  BACKEND_FILE="${TF_DIR}/stage/backend.tf"
fi

if [[ ! -f "$VAR_FILE" ]]; then
  error "Variable file not found: ${VAR_FILE}"
  exit 1
fi

# Parse values from tfvars (use ^key to avoid partial matches like dns_project_id)
PROJECT_ID=$(grep '^project_id ' "$VAR_FILE" | sed 's/.*= *"\(.*\)"/\1/')
CLUSTER_NAME=$(grep '^cluster_name ' "$VAR_FILE" | sed 's/.*= *"\(.*\)"/\1/')
SERVICE_NAME=$(grep '^service_name ' "$VAR_FILE" | sed 's/.*= *"\(.*\)"/\1/')
REGION="us-central1"
AR_REPO=$(grep '^ar_repository_name ' "$VAR_FILE" | sed 's/.*= *"\(.*\)"/\1/')

# Default region if not in tfvars
REGION="${REGION:-us-central1}"

PIPELINE_NAME="${SERVICE_NAME}-pipeline"

echo ""
echo "=============================================="
echo "  DESTROY: ${ENV} environment"
echo "=============================================="
echo "  Project:       ${PROJECT_ID}"
echo "  Cluster:       ${CLUSTER_NAME}"
echo "  Service:       ${SERVICE_NAME}"
echo "  Pipeline:      ${PIPELINE_NAME}"
echo "  Region:        ${REGION}"
echo "  AR Repository: ${AR_REPO}"
echo "=============================================="
echo ""

read -p "Are you sure you want to DESTROY all infrastructure for ${ENV}? (type 'yes' to confirm): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

# ---------- Step 1: Delete K8s workloads ----------
log "Step 1: Deleting Kubernetes workloads..."
if gcloud container clusters describe "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" &>/dev/null; then
  gcloud container clusters get-credentials "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" 2>/dev/null || true
  kubectl delete deployment gcp-clouddeploy-gke-template --ignore-not-found 2>/dev/null || true
  kubectl delete service gcp-clouddeploy-gke-template --ignore-not-found 2>/dev/null || true
  kubectl delete serviceaccount "${SERVICE_NAME}" --ignore-not-found 2>/dev/null || true
  # Delete Ingress and related resources (managed certificate, frontend config)
  kubectl delete ingress gcp-clouddeploy-gke-template --ignore-not-found 2>/dev/null || true
  kubectl delete managedcertificate gcp-clouddeploy-gke-template-cert --ignore-not-found 2>/dev/null || true
  kubectl delete frontendconfig gcp-clouddeploy-gke-template-frontend-config --ignore-not-found 2>/dev/null || true
  log "Kubernetes workloads deleted."
else
  warn "GKE cluster ${CLUSTER_NAME} not found — skipping K8s cleanup."
fi

# ---------- Step 2: Delete Cloud Deploy releases and pipeline ----------
log "Step 2: Cleaning up Cloud Deploy resources..."

# Delete all releases in the pipeline
if gcloud deploy delivery-pipelines describe "${PIPELINE_NAME}" --project="${PROJECT_ID}" --region="${REGION}" &>/dev/null; then
  RELEASES=$(gcloud deploy releases list \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --delivery-pipeline="${PIPELINE_NAME}" \
    --format="value(name.basename())" 2>/dev/null || true)

  if [[ -n "$RELEASES" ]]; then
    log "Deleting Cloud Deploy releases..."
    for RELEASE in $RELEASES; do
      log "  Deleting release: ${RELEASE}"
      gcloud deploy releases delete "${RELEASE}" \
        --project="${PROJECT_ID}" \
        --region="${REGION}" \
        --delivery-pipeline="${PIPELINE_NAME}" \
        --quiet 2>/dev/null || warn "  Failed to delete release ${RELEASE}"
    done
  fi

  # Delete the delivery pipeline
  log "Deleting Cloud Deploy delivery pipeline: ${PIPELINE_NAME}"
  gcloud deploy delivery-pipelines delete "${PIPELINE_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --force \
    --quiet 2>/dev/null || warn "Failed to delete delivery pipeline"
else
  warn "Cloud Deploy pipeline ${PIPELINE_NAME} not found — skipping."
fi

# Delete Cloud Deploy target
if gcloud deploy targets describe "${CLUSTER_NAME}" --project="${PROJECT_ID}" --region="${REGION}" &>/dev/null; then
  log "Deleting Cloud Deploy target: ${CLUSTER_NAME}"
  gcloud deploy targets delete "${CLUSTER_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --quiet 2>/dev/null || warn "Failed to delete Cloud Deploy target"
else
  warn "Cloud Deploy target ${CLUSTER_NAME} not found — skipping."
fi

# ---------- Step 3: Clean up Cloud Deploy artifacts bucket ----------
log "Step 3: Cleaning up Cloud Deploy artifacts in GCS..."
DEPLOY_BUCKET="gs://${REGION}.deploy-artifacts.${PROJECT_ID}.appspot.com"
if gsutil ls "${DEPLOY_BUCKET}" &>/dev/null; then
  gsutil -m rm -r "${DEPLOY_BUCKET}/${PIPELINE_NAME}-*" 2>/dev/null || warn "No deploy artifacts to clean up"
  log "Deploy artifacts cleaned."
else
  warn "Deploy artifacts bucket not found — skipping."
fi

# ---------- Step 4: Delete Artifact Registry images ----------
log "Step 4: Deleting Artifact Registry images..."
AR_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}"
if gcloud artifacts repositories describe "${AR_REPO}" --project="${PROJECT_ID}" --location="${REGION}" &>/dev/null; then
  IMAGES=$(gcloud artifacts docker images list "${AR_PATH}" --format="value(IMAGE)" --include-tags 2>/dev/null || true)
  if [[ -n "$IMAGES" ]]; then
    log "Deleting all images in ${AR_PATH}..."
    for IMG in $(echo "$IMAGES" | sort -u); do
      gcloud artifacts docker images delete "${IMG}" --project="${PROJECT_ID}" --quiet --delete-tags 2>/dev/null || warn "  Failed to delete ${IMG}"
    done
  fi
  log "Artifact Registry images cleaned."
else
  warn "Artifact Registry repository ${AR_REPO} not found — skipping."
fi

# ---------- Step 5: Terraform destroy ----------
log "Step 5: Running Terraform destroy..."
cd "${TF_DIR}"
cp "${BACKEND_FILE}" backend.tf

terraform init -input=false
terraform destroy \
  -var-file="${VAR_FILE}" \
  -var="image_tag=latest" \
  -auto-approve

log "Terraform destroy complete."

# ---------- Step 6: Clean up Cloud Build and Cloud Deploy buckets ----------
log "Step 6: Cleaning up Cloud Build and Cloud Deploy storage buckets..."

# Cloud Deploy source staging bucket (hash-based name)
SOURCE_BUCKETS=$(gsutil ls -p "${PROJECT_ID}" 2>/dev/null | grep "_clouddeploy" || true)
if [[ -n "$SOURCE_BUCKETS" ]]; then
  for BUCKET in $SOURCE_BUCKETS; do
    log "  Cleaning Cloud Deploy source bucket: ${BUCKET}"
    gsutil -m rm -r "${BUCKET}**" 2>/dev/null || warn "  Failed to clean ${BUCKET}"
  done
fi

# Cloud Build logs bucket (used by Cloud Deploy render/deploy steps)
CB_LOGS_BUCKET="gs://${PROJECT_ID}_cloudbuild"
if gsutil ls "${CB_LOGS_BUCKET}" &>/dev/null; then
  log "  Cleaning Cloud Build logs bucket: ${CB_LOGS_BUCKET}"
  gsutil -m rm -r "${CB_LOGS_BUCKET}/**" 2>/dev/null || warn "  Failed to clean Cloud Build logs bucket"
  log "  Cloud Build logs cleaned."
else
  warn "Cloud Build logs bucket not found — skipping."
fi

# Cloud Deploy artifacts bucket
DEPLOY_ARTIFACTS_BUCKET="gs://${REGION}.deploy-artifacts.${PROJECT_ID}.appspot.com"
if gsutil ls "${DEPLOY_ARTIFACTS_BUCKET}" &>/dev/null; then
  log "  Cleaning deploy artifacts bucket: ${DEPLOY_ARTIFACTS_BUCKET}"
  gsutil -m rm -r "${DEPLOY_ARTIFACTS_BUCKET}/**" 2>/dev/null || warn "  Failed to clean deploy artifacts bucket"
  log "  Deploy artifacts cleaned."
else
  warn "Deploy artifacts bucket not found — skipping."
fi

log "Storage cleanup complete."

echo ""
echo "=============================================="
echo -e "  ${GREEN}DESTROY COMPLETE: ${ENV} environment${NC}"
echo "=============================================="
echo ""
echo "The following resources have been destroyed:"
echo "  - Kubernetes workloads (deployment, service, service-account, ingress, managed-certificate, frontend-config)"
echo "  - Cloud Deploy pipeline, target, and releases"
echo "  - GKE Autopilot cluster: ${CLUSTER_NAME}"
echo "  - Artifact Registry repository: ${AR_REPO}"
echo "  - Firestore database"
echo "  - Static IP and DNS A record"
echo "  - Service accounts and IAM bindings"
echo "  - Cloud Deploy artifact and source buckets"
echo "  - Cloud Build logs"
echo ""
echo "Note: Terraform state in GCS bucket has been preserved."
echo "Note: GCP APIs have NOT been disabled (disable_on_destroy=false)."
echo "Note: Cloud Build execution history cannot be deleted (immutable GCP audit trail)."
echo ""
