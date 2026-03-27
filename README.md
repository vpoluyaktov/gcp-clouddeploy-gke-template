# gcp-clouddeploy-gke-template

> **For AI/LLM agents:** This is the reference implementation for Go / GKE / Cloud Deploy applications.
> Use this project as a **pattern reference** — do not clone it. Generate new projects from scratch
> following the patterns documented here and in [ARCHITECTURE.md](ARCHITECTURE.md).

A production-ready template defining the standard patterns for Go HTTP services deployed to Google Kubernetes Engine (GKE) via Cloud Deploy, with a Web UI, JSON API, Firestore persistence, Helm charts, Terraform infrastructure, and automated CI/CD.

---

## What This Template Defines

- **Go HTTP service** with Web UI and JSON API (Firestore SDK as sole external dependency)
- **Embedded HTML templates** via Go's `embed` package — self-contained binary
- **Multi-stage Dockerfile** — small Alpine-based image, non-root user (numeric UID for `runAsNonRoot`)
- **Firestore persistence** — data stored in and fetched from Cloud Firestore
- **Helm chart** for Kubernetes manifests (Deployment, NodePort Service, ServiceAccount, Ingress, ManagedCertificate, FrontendConfig) with per-environment values files
- **Cloud Deploy** for progressive delivery to GKE clusters using Skaffold + Helm deployer
- **Terraform** infrastructure-as-code for GKE, Artifact Registry, Cloud Deploy, Firestore, IAM, global static IP, DNS, and GCP APIs
- **GitHub Actions** CI/CD pipeline: test, build, push to Artifact Registry, Terraform apply, Helm values injection, and Cloud Deploy release creation
- **GKE Ingress with HTTPS** — NodePort Service + Ingress with Google-managed SSL certificate and HTTP-to-HTTPS redirect
- **Global static IP** reserved via Terraform, referenced by name in the Ingress annotation and used in the DNS A record
- **Multi-environment** deployment: `stage` branch → staging, `main` branch → production
- **Path-filtered triggers** — deploy only runs when app, infra, or Helm files change; manual `workflow_dispatch` for on-demand deploys
- **Separate GCP projects** and service accounts per environment
- **Destroy script** (`scripts/destroy.sh`) to tear down all cloud infrastructure

> For the complete architecture reference (all structs, handlers, Terraform resources, design decisions), see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Local Development

```bash
cd service
go run .
```

The service starts on `http://localhost:8080` with default config (`PORT=8080`, `APP_VERSION=dev`, `ENVIRONMENT=local`).

Without `GCP_PROJECT_ID` set, the service runs without Firestore and falls back to a hardcoded greeting.

### Run Tests

```bash
cd service
go test ./...
go vet ./...
```

---

## Creating a New Application from This Template

**DO NOT clone or copy this repository.** Instead, generate every file from scratch in the new project directory, following the patterns defined here. This ensures all files use the correct application name from the start with no leftover template references.

### Step 1: Generate the Project

Create a new empty directory for the application and generate all files following these patterns:

**Directory structure to create:**
```
<app-name>/
├── VERSION                            # Contains "1.0"
├── ARCHITECTURE.md                    # Architecture reference (adapted for the new app)
├── README.md                          # Project README (adapted for the new app)
├── .gitignore                         # Excludes terraform/.terraform/, *.tfstate, vendor/, IDE files
├── skaffold.yaml                      # Skaffold config with Helm deployer and env profiles
├── service/
│   ├── main.go                        # Entry point (same pattern as template)
│   ├── go.mod                         # Module: <app-name>, same dependencies
│   ├── Dockerfile                     # Multi-stage build (binary name = <app-name>)
│   └── internal/
│       ├── config/
│       │   ├── config.go              # Config struct with env var loading
│       │   └── config_test.go         # Config tests
│       ├── server/
│       │   ├── server.go              # Server struct, constructor, routes
│       │   ├── handlers.go            # HTTP handlers
│       │   └── server_test.go         # Handler tests with mock store
│       ├── store/
│       │   └── store.go               # Store interface + FirestoreStore
│       └── templates/
│           ├── templates.go           # embed.FS for index.html
│           └── index.html             # HTML template with inline CSS/JS
├── helm/
│   ├── Chart.yaml                     # Helm chart metadata
│   ├── values.yaml                    # Default values (shared across environments)
│   ├── values-staging.yaml            # Staging environment overrides (incl. ingress domain, static IP name)
│   ├── values-production.yaml         # Production environment overrides (incl. ingress domain, static IP name)
│   └── templates/
│       ├── deployment.yaml            # Helm-templated Deployment
│       ├── service.yaml               # NodePort Service (traffic routed through Ingress)
│       ├── service-account.yaml       # Helm-templated K8s SA with Workload Identity annotation
│       ├── ingress.yaml               # GKE Ingress with global static IP and managed SSL cert
│       ├── managed-certificate.yaml   # Google-managed SSL certificate for the custom domain
│       └── frontend-config.yaml       # HTTP-to-HTTPS redirect configuration
├── scripts/
│   └── destroy.sh                     # Tears down all cloud infrastructure for an environment
├── terraform/
│   ├── main.tf                        # Google provider config
│   ├── variables.tf                   # All input variables
│   ├── versions.tf                    # Terraform >= 1.0, google ~> 5.0
│   ├── gke.tf                         # GKE Autopilot cluster (deletion_protection = false)
│   ├── iam.tf                         # Runtime SA + Workload Identity binding
│   ├── dns.tf                         # Global static IP (google_compute_global_address) + DNS A record
│   ├── firestore.tf                   # Firestore database + seed document
│   ├── apis.tf                        # Enable required GCP APIs
│   ├── artifact-registry.tf           # Artifact Registry Docker repo
│   ├── clouddeploy.tf                 # Cloud Deploy pipeline + target + execution SA
│   ├── outputs.tf                     # Terraform outputs (including gke_lb_ip, gke_lb_ip_name)
│   ├── stage/
│   │   ├── backend.tf                 # GCS backend for staging
│   │   └── stage.tfvars               # Staging variable values
│   └── prod/
│       ├── backend.tf                 # GCS backend for production
│       └── prod.tfvars                # Production variable values
└── .github/
    └── workflows/
        └── main.yml                   # CI/CD: test + build + deploy (path-filtered + workflow_dispatch)
```

**After generating files**, run:
```bash
cd <app-name>/service
go mod tidy
```
This generates `go.sum` and resolves all dependencies.

### Step 2: Read Template Source Files for Exact Patterns

When generating each file, read the corresponding template source file to understand the exact pattern:

| New Project File | Template Reference File |
|-----------------|------------------------|
| `service/main.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/main.go` |
| `service/internal/config/config.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/config/config.go` |
| `service/internal/server/server.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/server/server.go` |
| `service/internal/server/handlers.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/server/handlers.go` |
| `service/internal/store/store.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/store/store.go` |
| `service/internal/templates/templates.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/templates/templates.go` |
| `service/internal/templates/index.html` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/templates/index.html` |
| `service/Dockerfile` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/Dockerfile` |
| `service/go.mod` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/go.mod` |
| `helm/Chart.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/Chart.yaml` |
| `helm/values.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/values.yaml` |
| `helm/values-staging.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/values-staging.yaml` |
| `helm/values-production.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/values-production.yaml` |
| `helm/templates/deployment.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/templates/deployment.yaml` |
| `helm/templates/service.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/templates/service.yaml` |
| `helm/templates/service-account.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/templates/service-account.yaml` |
| `helm/templates/ingress.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/templates/ingress.yaml` |
| `helm/templates/managed-certificate.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/templates/managed-certificate.yaml` |
| `helm/templates/frontend-config.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/helm/templates/frontend-config.yaml` |
| `skaffold.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/skaffold.yaml` |
| `terraform/*.tf` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/terraform/*.tf` |
| `.github/workflows/main.yml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/.github/workflows/main.yml` |
| `scripts/destroy.sh` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/scripts/destroy.sh` |
| `service/internal/server/server_test.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/server/server_test.go` |
| `service/internal/config/config_test.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/config/config_test.go` |

### Step 3: Adapt Application-Specific Details

Replace template-specific values with the new application's values:

| Template Value | Replace With |
|---------------|-------------|
| `gcp-clouddeploy-gke-template` (Go module, Docker image, Helm chart name, Terraform refs) | `<app-name>` |
| `gke-tpl` (runtime SA prefix) | Short prefix for `<app-name>` (full SA ID with `-<environment>` suffix must be ≤ 30 chars) |
| `deploy-gke-tpl` (Cloud Deploy execution SA prefix) | Short prefix for `<app-name>` Cloud Deploy execution SA |
| `"Hello World!"` greeting and `/api/hello` endpoint | The new application's actual API endpoints and business logic |
| `greetings/hello` Firestore document | The new application's Firestore collection/document structure |
| Template UI (gradient text, particles) | The new application's UI design |
| `helm/values-staging.yaml` and `helm/values-production.yaml` | Environment-specific values (project IDs, SA names, SA emails, ingress domain, static IP name) for the new app |

---

## Infrastructure Configuration

### GCP Environments

| Environment | GCP Project | Branch | State Bucket |
|-------------|------------|--------|-------------|
| **Staging** | `dfh-stage-id` | `stage` | `dfh-stage-tfstate` |
| **Production** | `dfh-prod-id` | `main` | `dfh-prod-tfstate` |
| **DNS/Ops** | `dfh-ops-id` | — | — |

### Terraform Variable Values

**`terraform/stage/stage.tfvars`** — generate with these values:
```hcl
project_id              = "dfh-stage-id"
service_name            = "<app-name>-stage"
environment             = "staging"
tfstate_bucket_name     = "dfh-stage-tfstate"
cluster_name            = "<app-short>-stage"
dns_project_id          = "dfh-ops-id"
dns_zone_name           = "demo-devops-for-hire-com"
dns_domain              = "demo.devops-for-hire.com"
custom_domain           = "<app-name>.stage.demo.devops-for-hire.com"
firestore_database_name = "<app-name>"
ar_repository_name      = "<app-name>"
```

**`terraform/prod/prod.tfvars`** — generate with these values:
```hcl
project_id              = "dfh-prod-id"
service_name            = "<app-name>-prod"
environment             = "production"
tfstate_bucket_name     = "dfh-prod-tfstate"
cluster_name            = "<app-short>-prod"
dns_project_id          = "dfh-ops-id"
dns_zone_name           = "demo-devops-for-hire-com"
dns_domain              = "demo.devops-for-hire.com"
custom_domain           = "<app-name>.demo.devops-for-hire.com"
firestore_database_name = "<app-name>"
ar_repository_name      = "<app-name>"
```

**`terraform/stage/backend.tf`:**
```hcl
terraform {
  backend "gcs" {
    bucket = "dfh-stage-tfstate"
    prefix = "<app-name>/state"
  }
}
```

**`terraform/prod/backend.tf`:**
```hcl
terraform {
  backend "gcs" {
    bucket = "dfh-prod-tfstate"
    prefix = "<app-name>/state"
  }
}
```

### Custom Domain Setup

Each service gets DNS names under `demo.devops-for-hire.com`:

| Environment | Domain |
|-------------|--------|
| Staging | `<app-name>.stage.demo.devops-for-hire.com` |
| Production | `<app-name>.demo.devops-for-hire.com` |

DNS A records are managed by Terraform (`dns.tf`), pointing to a **global static IP** reserved by Terraform (`google_compute_global_address`). The static IP is referenced by **name** (not address) in the GKE Ingress annotation (`kubernetes.io/ingress.global-static-ip-name`). A Google-managed SSL certificate auto-provisions HTTPS, and a FrontendConfig redirects HTTP to HTTPS. This ensures stable DNS, automatic TLS, and HTTPS-by-default across redeployments.

**IMPORTANT:** GKE Ingress requires a **global** static IP, not a regional one. The Ingress references the IP by resource name, not by address value.

---

## Service Accounts

Each environment uses **three service accounts**:

| SA Type | Naming Convention | Managed By | Purpose |
|---------|-------------------|------------|---------|
| **Deploy SA** | `gcp-cloudrun-deploy@<project>.iam.gserviceaccount.com` | Pre-existing in each project | GitHub Actions: push images, Terraform apply, create Cloud Deploy releases |
| **Cloud Deploy Execution SA** | `deploy-<sa-prefix>-<env>@<project>.iam.gserviceaccount.com` | Terraform (`clouddeploy.tf`) | Cloud Deploy: render manifests and deploy to GKE |
| **Runtime SA** | `<sa-prefix>-<env>@<project>.iam.gserviceaccount.com` | Terraform (`iam.tf`) | GKE pod identity via Workload Identity (logging + Firestore access) |

### Deploy SA Required Roles

The deploy SA in each project must have these roles:

- `roles/artifactregistry.admin`
- `roles/clouddeploy.admin`
- `roles/compute.admin`
- `roles/container.admin`
- `roles/datastore.owner`
- `roles/dns.admin` on `dfh-ops-id` (for cross-project DNS management)
- `roles/iam.serviceAccountAdmin`
- `roles/iam.serviceAccountUser`
- `roles/logging.logWriter`
- `roles/resourcemanager.projectIamAdmin`
- `roles/serviceusage.serviceUsageAdmin`
- `roles/storage.admin`

### GitHub Secrets

| Secret | Description |
|--------|-------------|
| `GCP_STAGE_SA_KEY` | JSON key for deploy SA in `dfh-stage-id` |
| `GCP_PROD_SA_KEY` | JSON key for deploy SA in `dfh-prod-id` |

These secrets are already configured for existing projects. For new GitHub repos, set them with:
```bash
gh secret set GCP_STAGE_SA_KEY < /path/to/stage-key.json
gh secret set GCP_PROD_SA_KEY < /path/to/prod-key.json
```

### Cloud Deploy Execution SA Roles (Managed by Terraform)

- `roles/container.developer`
- `roles/logging.logWriter`
- `roles/storage.objectAdmin`
- `roles/artifactregistry.reader`

### Runtime SA Roles (Managed by Terraform)

- `roles/logging.logWriter`
- `roles/datastore.user`

---

## Helm Chart

The application uses a Helm chart (`helm/`) instead of raw Kubernetes manifests. This provides clean separation of environment-specific values from templates.

### Values Architecture

| File | Purpose | Managed By |
|------|---------|------------|
| `helm/values.yaml` | Default values (replicas, ports, probes, resources) | Committed in repo |
| `helm/values-staging.yaml` | Staging overrides (project ID, SA names, SA emails, ingress domain/IP name) | Committed in repo |
| `helm/values-production.yaml` | Production overrides (project ID, SA names, SA emails, ingress domain/IP name) | Committed in repo |
| `helm/values-dynamic.yaml` | Dynamic values (app version only) | Generated by CI at build time |

### Dynamic Values

Only one value is injected at CI time (written to `helm/values-dynamic.yaml`):

| Value | Source |
|-------|--------|
| `app.version` | Computed from `VERSION` file + commit count |

The static IP is referenced by **name** (not address) in the Ingress annotation, and that name is committed in the per-environment values files. All other values (environment, project ID, SA names, SA emails, ingress domain, static IP name) are pre-committed in per-environment values files.

### Image Substitution

The container image is **not** set via Helm values. Instead, the Helm deployment template uses the placeholder `image: gcp-clouddeploy-gke-template`, which Skaffold replaces with the actual Artifact Registry image URI via the `--images` flag during Cloud Deploy rendering.

---

## Environment Variables

The service reads these environment variables at startup:

| Variable | Default | Set By | Description |
|----------|---------|--------|-------------|
| `PORT` | `8080` | Helm values | HTTP listen port |
| `APP_VERSION` | `dev` | Helm `values-dynamic.yaml` (CI-injected) | Version string displayed in UI and API |
| `ENVIRONMENT` | `local` | Helm `values-<env>.yaml` | Environment name (staging/production/local) |
| `GCP_PROJECT_ID` | `""` | Helm `values-<env>.yaml` | GCP project ID for Firestore. If empty, Firestore is disabled. |
| `FIRESTORE_DATABASE_NAME` | `(default)` | Helm `values-<env>.yaml` | Firestore database name (typically the application name) |

---

## Versioning

- `VERSION` file at repo root contains `MAJOR.MINOR` (e.g., `1.0`)
- CI/CD computes full version: `MAJOR.MINOR.<commit_count>` (e.g., `1.0.42`)
- Docker images are tagged `v1.0.42` and `latest`
- Bump `VERSION` when making breaking or feature changes

---

## Deployment Flow

### Triggers

| Trigger | What Runs |
|---------|-----------|
| Push to `main`/`stage` changing `service/`, `helm/`, `terraform/`, `skaffold.yaml`, or `VERSION` | Full pipeline: test → build → deploy |
| Push to `main`/`stage` changing only `scripts/`, `*.md`, `.github/workflows/`, etc. | **Nothing** (no workflow triggered) |
| Pull request to `main`/`stage` | Test job only (no build or deployment) |
| Manual **workflow_dispatch** (GitHub Actions UI → "Run workflow") | Full pipeline: test → build → deploy (with environment selector) |

### Pipeline Flow

```
git push (matching paths) → GitHub Actions:
  1. test (Go test, vet, lint)
  2. build-and-deploy:
     a. Terraform apply (GKE, Cloud Deploy, global static IP, DNS, etc.)
     b. Docker build + push to Artifact Registry
     c. Generate helm/values-dynamic.yaml (version only)
     d. Create Cloud Deploy release with --source=. (Skaffold + Helm render → deploy to GKE)
     e. Wait for rollout + smoke test
```

| Branch | Environment | GCP Project |
|--------|-------------|-------------|
| `stage` | Staging | `dfh-stage-id` |
| `main` | Production | `dfh-prod-id` |

### Push and Deploy Sequence

```bash
# Initialize git and push
git init
git checkout -b main
git add -A
git commit -m "Initial commit"

# Create GitHub repo and push
gh repo create <org>/<app-name> --private --source=. --push

# Create and push stage branch (triggers staging build+deploy)
git checkout -b stage
git push origin stage

# Switch back to main
git checkout main
```

---

## Destroying Infrastructure

Use the destroy script to tear down all cloud resources for an environment:

```bash
./scripts/destroy.sh <prod|stage>
```

The script performs these steps in order:
1. Deletes Kubernetes workloads (deployment, service, service-account, ingress, managed-certificate, frontend-config) via kubectl
2. Deletes Cloud Deploy releases, delivery pipeline, and target
3. Cleans Cloud Deploy artifact buckets in GCS
4. Deletes all Artifact Registry images
5. Runs `terraform destroy` (GKE cluster, Firestore, global static IP, DNS, SAs, IAM bindings)
6. Cleans Cloud Build logs and Cloud Deploy source staging buckets

The script requires interactive confirmation, is idempotent, and preserves the Terraform state bucket and GCP projects.

---

## Project Structure at a Glance

```
service/                → Go application code
service/internal/       → Private packages (config, server, store, templates)
service/Dockerfile      → Multi-stage Docker build (non-root, numeric UID)
helm/                   → Helm chart (Chart.yaml, values files, templates)
helm/templates/         → Kubernetes manifest templates (deployment, service, service-account, ingress, managed-certificate, frontend-config)
helm/values-*.yaml      → Per-environment values (staging, production, dynamic)
skaffold.yaml           → Skaffold config with Helm deployer + environment profiles
scripts/                → Operational scripts (destroy.sh)
terraform/              → Shared Terraform modules
terraform/stage/        → Staging environment config (backend.tf, stage.tfvars)
terraform/prod/         → Production environment config (backend.tf, prod.tfvars)
.github/workflows/      → CI/CD pipeline (path-filtered + workflow_dispatch)
.gitignore              → Excludes .terraform/, *.tfstate, vendor/, IDE files
VERSION                 → Semantic version (MAJOR.MINOR)
ARCHITECTURE.md         → Detailed architecture reference
```

For the complete architecture reference including all structs, handlers, Terraform resources, and design decisions, see [ARCHITECTURE.md](ARCHITECTURE.md).
