# gcp-clouddeploy-gke-template

> **For AI/LLM agents:** This is the reference implementation for Go / GKE / Cloud Deploy applications.
> Use this project as a **pattern reference** — do not clone it. Generate new projects from scratch
> following the patterns documented here and in [ARCHITECTURE.md](ARCHITECTURE.md).

A production-ready template defining the standard patterns for Go HTTP services deployed to Google Kubernetes Engine (GKE) via Cloud Deploy, with a Web UI, JSON API, Firestore persistence, Terraform infrastructure, and automated CI/CD.

---

## What This Template Defines

- **Go HTTP service** with Web UI and JSON API (Firestore SDK as sole external dependency)
- **Embedded HTML templates** via Go's `embed` package — self-contained binary
- **Multi-stage Dockerfile** — small Alpine-based image, non-root user
- **Firestore persistence** — data stored in and fetched from Cloud Firestore
- **Kubernetes manifests** for Deployment and LoadBalancer Service
- **Cloud Deploy** for progressive delivery to GKE clusters
- **Terraform** infrastructure-as-code for GKE, Artifact Registry, Cloud Deploy, Firestore, IAM, DNS, and GCP APIs
- **GitHub Actions** CI/CD pipeline: test, build, push to Artifact Registry, Terraform apply, and Cloud Deploy release creation
- **Multi-environment** deployment: `stage` branch → staging, `main` branch → production
- **Separate GCP projects** and service accounts per environment

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
├── skaffold.yaml                      # Skaffold config for Cloud Deploy
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
├── k8s/
│   ├── deployment.yaml                # Kubernetes Deployment manifest
│   └── service.yaml                   # Kubernetes Service manifest
├── terraform/
│   ├── main.tf                        # Google provider config
│   ├── variables.tf                   # All input variables
│   ├── versions.tf                    # Terraform >= 1.0, google ~> 5.0
│   ├── gke.tf                         # GKE Autopilot cluster
│   ├── iam.tf                         # Runtime SA + Workload Identity binding
│   ├── dns.tf                         # A record in Cloud DNS
│   ├── firestore.tf                   # Firestore database + seed document
│   ├── apis.tf                        # Enable required GCP APIs
│   ├── artifact-registry.tf           # Artifact Registry Docker repo
│   ├── clouddeploy.tf                 # Cloud Deploy pipeline + target + execution SA
│   ├── outputs.tf                     # Terraform outputs
│   ├── stage/
│   │   ├── backend.tf                 # GCS backend for staging
│   │   └── stage.tfvars               # Staging variable values
│   └── prod/
│       ├── backend.tf                 # GCS backend for production
│       └── prod.tfvars                # Production variable values
└── .github/
    └── workflows/
        └── main.yml                   # Full CI/CD: test → build → terraform → Cloud Deploy release
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
| `k8s/deployment.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/k8s/deployment.yaml` |
| `k8s/service.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/k8s/service.yaml` |
| `skaffold.yaml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/skaffold.yaml` |
| `terraform/*.tf` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/terraform/*.tf` |
| `.github/workflows/main.yml` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/.github/workflows/main.yml` |
| `service/internal/server/server_test.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/server/server_test.go` |
| `service/internal/config/config_test.go` | `/home/ubuntu/git/gcp-clouddeploy-gke-template/service/internal/config/config_test.go` |

### Step 3: Adapt Application-Specific Details

Replace template-specific values with the new application's values:

| Template Value | Replace With |
|---------------|-------------|
| `gcp-clouddeploy-gke-template` (Go module, Docker image, Terraform refs) | `<app-name>` |
| `gke-tpl` (runtime SA prefix) | Short prefix for `<app-name>` (full SA ID with `-<environment>` suffix must be ≤ 30 chars) |
| `deploy-gke-tpl` (Cloud Deploy execution SA prefix) | Short prefix for `<app-name>` Cloud Deploy execution SA |
| `"Hello World!"` greeting and `/api/hello` endpoint | The new application's actual API endpoints and business logic |
| `greetings/hello` Firestore document | The new application's Firestore collection/document structure |
| Template UI (gradient text, particles) | The new application's UI design |

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

DNS A records are managed by Terraform (`dns.tf`), pointing to the GKE LoadBalancer external IP. Unlike Cloud Run, there is no domain mapping step — the DNS record points directly to the Kubernetes Service's external IP.

> **Note:** The external IP is only available after the Kubernetes Service is created and an IP is assigned by GCP. On initial deploy, the DNS record may need to be updated after the LoadBalancer IP is allocated.

---

## Service Accounts

Each environment uses **three service accounts**:

| SA Type | Naming Convention | Managed By | Purpose |
|---------|-------------------|------------|---------|
| **Deploy SA** | `gcp-cloudrun-deploy@<project>.iam.gserviceaccount.com` | Pre-existing in each project | GitHub Actions: push images, Terraform apply, create Cloud Deploy releases |
| **Cloud Deploy Execution SA** | `deploy-<sa-prefix>-<env>@<project>.iam.gserviceaccount.com` | Terraform (`clouddeploy.tf`) | Cloud Deploy: render manifests and deploy to GKE |
| **Runtime SA** | `<sa-prefix>-<env>@<project>.iam.gserviceaccount.com` | Terraform (`iam.tf`) | GKE pod identity (logging + Firestore access) |

### Deploy SA Required Roles

The deploy SA in each project must have these roles:

- `roles/artifactregistry.admin`
- `roles/clouddeploy.admin`
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
- `roles/storage.objectViewer`
- `roles/artifactregistry.reader`

### Runtime SA Roles (Managed by Terraform)

- `roles/logging.logWriter`
- `roles/datastore.user`

---

## Environment Variables

The service reads these environment variables at startup:

| Variable | Default | Set By | Description |
|----------|---------|--------|-------------|
| `PORT` | `8080` | Kubernetes | HTTP listen port |
| `APP_VERSION` | `dev` | Kubernetes Deployment manifest | Version string displayed in UI and API |
| `ENVIRONMENT` | `local` | Kubernetes Deployment manifest | Environment name (staging/production/local) |
| `GCP_PROJECT_ID` | `""` | Kubernetes Deployment manifest | GCP project ID for Firestore. If empty, Firestore is disabled. |
| `FIRESTORE_DATABASE_NAME` | `(default)` | Kubernetes Deployment manifest | Firestore database name (typically the application name) |

---

## Versioning

- `VERSION` file at repo root contains `MAJOR.MINOR` (e.g., `1.0`)
- CI/CD computes full version: `MAJOR.MINOR.<commit_count>` (e.g., `1.0.42`)
- Docker images are tagged `v1.0.42` and `latest`
- Bump `VERSION` when making breaking or feature changes

---

## Deployment Flow

```
git push origin stage  →  GitHub Actions (test → build → push to AR → terraform apply → Cloud Deploy release) → GKE staging
git push origin main   →  GitHub Actions (test → build → push to AR → terraform apply → Cloud Deploy release) → GKE production
```

| Branch | Environment | GCP Project | Deployed On |
|--------|-------------|-------------|-------------|
| `stage` | Staging | `dfh-stage-id` | Every push to `stage` |
| `main` | Production | `dfh-prod-id` | Every push to `main` |

Pull requests to either branch run the test job only (no build or deployment).

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

## Project Structure at a Glance

```
service/                → Go application code
service/internal/       → Private packages (config, server, store, templates)
service/Dockerfile      → Multi-stage Docker build
k8s/                    → Kubernetes manifests (Deployment, Service)
skaffold.yaml           → Skaffold config for Cloud Deploy
terraform/              → Shared Terraform modules
terraform/stage/        → Staging environment config
terraform/prod/         → Production environment config
.github/workflows/      → Full CI/CD pipeline (test + build + deploy)
VERSION                 → Semantic version (MAJOR.MINOR)
ARCHITECTURE.md         → Detailed architecture reference
```

For the complete architecture reference including all structs, handlers, Terraform resources, and design decisions, see [ARCHITECTURE.md](ARCHITECTURE.md).
