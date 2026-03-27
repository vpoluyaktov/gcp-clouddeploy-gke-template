# gcp-clouddeploy-gke-template Architecture

> **For AI/LLM agents:** This document is the authoritative reference for this codebase.
> When building a new project from this template, read this file first, then follow
> the step-by-step instructions in [README.md](README.md).

---

## Overview

A production-ready Go HTTP service template deployed to Google Kubernetes Engine (GKE) via Cloud Deploy with multi-environment CI/CD. It provides:

- A **Web UI** (Go `html/template` with embedded HTML/CSS/JS) that dynamically fetches content from the API
- A **JSON API** with health check and application endpoints
- A **Firestore persistence layer** for storing and fetching dynamic content
- **Helm chart** for Kubernetes manifests with per-environment values files
- **Terraform** infrastructure-as-code for GKE, Cloud Deploy, Artifact Registry, Firestore, static IP, DNS, and IAM provisioning
- **Cloud Deploy** for progressive delivery to GKE clusters using Skaffold + Helm deployer
- **GitHub Actions** CI/CD with path-filtered triggers, manual `workflow_dispatch`, and branch-based environment determination

This repo is designed as a **pattern reference** — generate new projects from scratch following these patterns. Do not clone it.

---

## Endpoints

| Method | Path         | Response Type      | Description |
|--------|--------------|--------------------|-------------|
| GET    | `/`          | `text/html`        | Web UI — renders the embedded HTML template with `Version` and `Environment` data. The UI fetches its greeting from `/api/hello` via JavaScript `fetch()`. |
| GET    | `/health`    | `application/json` | Health check: `{"status":"ok","version":"...","environment":"..."}` — used as Kubernetes liveness/readiness probe |
| GET    | `/api/hello` | `application/json` | JSON greeting fetched from Firestore: `{"message":"Hello World!","version":"...","timestamp":"..."}`. Falls back to hardcoded `"Hello World!"` if Firestore is unavailable. |

---

## Directory Structure

```
gcp-clouddeploy-gke-template/
├── README.md                          # Setup guide, template usage instructions
├── ARCHITECTURE.md                    # This file — authoritative architecture reference
├── VERSION                            # Semantic version (MAJOR.MINOR), patch = commit count
├── .gitignore                         # Excludes .terraform/, *.tfstate, vendor/, IDE files
│
├── service/                           # Go application source
│   ├── main.go                        # Entrypoint: config → server → listen → graceful shutdown
│   ├── go.mod                         # Go module (go 1.21, cloud.google.com/go/firestore)
│   ├── Dockerfile                     # Multi-stage: golang:1.21-alpine → alpine:latest
│   └── internal/
│       ├── config/
│       │   ├── config.go              # Config struct: Port, Version, Environment, ProjectID, FirestoreDatabaseName
│       │   └── config_test.go         # Tests: default values, env var loading
│       ├── server/
│       │   ├── server.go              # Server struct, New() constructor, SetupRoutes()
│       │   ├── server_test.go         # Tests: health, API, index, template parsing, mock store
│       │   └── handlers.go            # HTTP handlers: handleHealth, handleAPIHello, handleIndex
│       ├── store/
│       │   └── store.go               # Store interface + FirestoreStore implementation
│       └── templates/
│           ├── templates.go           # embed.FS exporting index.html for compile-time embedding
│           └── index.html             # Go html/template — full UI with CSS/JS
│
├── helm/                              # Helm chart for Kubernetes manifests
│   ├── Chart.yaml                     # Chart metadata (name, version)
│   ├── values.yaml                    # Default values (replicas, ports, probes, resources)
│   ├── values-staging.yaml            # Staging overrides (project ID, SA names, SA emails, ingress domain)
│   ├── values-production.yaml         # Production overrides (project ID, SA names, SA emails, ingress domain)
│   └── templates/
│       ├── deployment.yaml            # Deployment with Helm-templated env vars, probes, resources
│       ├── service.yaml               # NodePort Service (traffic routed through Ingress)
│       ├── service-account.yaml       # K8s ServiceAccount with Workload Identity annotation
│       ├── ingress.yaml               # GKE Ingress with global static IP and managed SSL cert
│       ├── managed-certificate.yaml   # Google-managed SSL certificate for the custom domain
│       └── frontend-config.yaml       # HTTP-to-HTTPS redirect configuration
│
├── scripts/                           # Operational scripts
│   └── destroy.sh                     # Tears down all cloud infrastructure for an environment
│
├── skaffold.yaml                      # Skaffold config with Helm deployer + environment profiles
│
├── terraform/                         # Shared Terraform modules (used by all environments)
│   ├── main.tf                        # Google Cloud provider configuration
│   ├── variables.tf                   # Input variables (project_id, region, cluster_name, etc.)
│   ├── versions.tf                    # Terraform >= 1.0, google provider ~> 5.0
│   ├── gke.tf                         # GKE Autopilot cluster (deletion_protection = false)
│   ├── iam.tf                         # Runtime SA + Workload Identity binding
│   ├── dns.tf                         # Global static IP (google_compute_global_address) + DNS A record
│   ├── firestore.tf                   # Firestore database + seed greeting document
│   ├── apis.tf                        # Enables required GCP APIs
│   ├── artifact-registry.tf           # Artifact Registry Docker repository
│   ├── clouddeploy.tf                 # Cloud Deploy pipeline + target + execution SA
│   ├── outputs.tf                     # Outputs: cluster_endpoint, service_account_email, gke_lb_ip, gke_lb_ip_name
│   ├── stage/
│   │   ├── backend.tf                 # GCS backend: bucket=dfh-stage-tfstate
│   │   └── stage.tfvars               # project_id=dfh-stage-id, cluster config
│   └── prod/
│       ├── backend.tf                 # GCS backend: bucket=dfh-prod-tfstate
│       └── prod.tfvars                # project_id=dfh-prod-id, cluster config
│
└── .github/
    └── workflows/
        └── main.yml                   # CI/CD: test + build + deploy (path-filtered + workflow_dispatch)
```

---

## Service Architecture

### Entry Point: `service/main.go`

```
config.Load() → store.NewFirestoreStore() → server.New(cfg, store) → srv.SetupRoutes() → http.ListenAndServe(:PORT) → graceful shutdown
```

- Reads config from environment variables via `config.Load()`
- Initializes Firestore store if `GCP_PROJECT_ID` is set (skips in local dev)
- Constructs `server.Server` with config and store (parses HTML template once at init)
- Starts HTTP listener on `PORT` (default: `8080`)
- Graceful shutdown on SIGINT/SIGTERM with 10-second timeout

### Package: `config` — `service/internal/config/`

| Field         | Env Var         | Default   | Description |
|---------------|-----------------|-----------|-------------|
| `Port`        | `PORT`          | `"8080"`  | HTTP listen port |
| `Version`     | `APP_VERSION`   | `"dev"`   | Application version (set by CI/CD) |
| `Environment` | `ENVIRONMENT`   | `"local"` | Environment name (staging/production) |
| `ProjectID`   | `GCP_PROJECT_ID` | `""`     | GCP project ID for Firestore |
| `FirestoreDatabaseName` | `FIRESTORE_DATABASE_NAME` | `"(default)"` | Firestore database name |

- `Load() *Config` — reads env vars, applies defaults, returns config struct
- No external dependencies — uses only `os.Getenv()`

### Package: `server` — `service/internal/server/`

**Struct:**
```go
type Server struct {
    cfg       *config.Config
    store     store.Store           // Firestore-backed (or nil for local dev)
    indexTmpl *template.Template   // parsed once in New()
}
```

**Constructor:**
- `New(cfg *config.Config, st store.Store) *Server` — parses `index.html` from `templates.FS` via `template.ParseFS()`

**Routes (registered in `SetupRoutes()`):**

| Route        | Handler           | Behavior |
|-------------|-------------------|----------|
| `/health`   | `handleHealth`    | Returns JSON `healthResponse{Status, Version, Environment}` |
| `/api/hello` | `handleAPIHello` | Fetches greeting from Firestore via `store.GetGreeting()`, falls back to `"Hello World!"` on error. Returns JSON `helloResponse{Message, Version, Timestamp}` |
| `/`         | `handleIndex`     | Executes pre-parsed HTML template with `indexData{Version, Environment}` |

**Response structs:**
- `healthResponse` — `status`, `version`, `environment`
- `helloResponse` — `message`, `version`, `timestamp`
- `indexData` — `Version`, `Environment` (passed to HTML template)

### Package: `store` — `service/internal/store/`

**Interface:**
```go
type Store interface {
    GetGreeting(ctx context.Context) (string, error)
    Close() error
}
```

**Implementation: `FirestoreStore`**
- `NewFirestoreStore(ctx, projectID, databaseName, opts...) (*FirestoreStore, error)` — creates Firestore client
- `GetGreeting(ctx)` — reads `greetings/hello` document, returns the `message` field
- `Close()` — closes the Firestore client connection

The `Store` interface enables dependency injection — tests use a mock implementation, production uses `FirestoreStore`.

### Package: `templates` — `service/internal/templates/`

```go
//go:embed index.html
var FS embed.FS
```

- `templates.go` exports a single `embed.FS` variable containing `index.html`
- `index.html` is a Go `html/template` with:
  - Inline CSS (gradient text, animated particle background, responsive layout)
  - Inline JavaScript that calls `fetch('/api/hello')` and displays the greeting dynamically
  - Template variables: `{{.Version}}` and `{{.Environment}}`
- The template is embedded at compile time — the binary is fully self-contained

### UI → API Pattern

The web UI does **not** hardcode content. Instead:
1. The HTML template renders with a "Loading..." placeholder
2. On page load, JavaScript calls `GET /api/hello`
3. The response's `message` field replaces the placeholder in the `<h1>` element

This pattern demonstrates a proper frontend-to-backend separation. The greeting message is fetched from Firestore, making the content fully dynamic and database-driven.

---

## Dockerfile

```
Stage 1 — Builder (golang:1.21-alpine):
  WORKDIR /app
  COPY go.mod → go mod download
  COPY . → CGO_ENABLED=0 GOOS=linux go build -o gcp-clouddeploy-gke-template .

Stage 2 — Runtime (alpine:latest):
  apk add ca-certificates tzdata
  addgroup -g 1001 rdapp && adduser -u 1001 rdapp (non-root, numeric UID)
  USER 1001
  COPY --from=builder /app/gcp-clouddeploy-gke-template .
  EXPOSE 8080
  HEALTHCHECK wget -qO- http://localhost:8080/health
  CMD ["./gcp-clouddeploy-gke-template"]
```

**Key points:**
- Static binary with `CGO_ENABLED=0` — no C dependencies
- Non-root user `rdapp` with **numeric UID 1001** — required for Kubernetes `runAsNonRoot` security context (K8s cannot verify non-root with named users)
- Built-in Docker HEALTHCHECK on `/health`
- Alpine runtime for small image with shell access for debugging

---

## Helm Chart

The application uses a Helm chart (`helm/`) instead of raw Kubernetes manifests. This provides clean separation of environment-specific values from templates.

### Values Architecture

| File | Purpose | Managed By |
|------|---------|------------|
| `helm/values.yaml` | Default values (replicas, ports, probes, resources) | Committed in repo |
| `helm/values-staging.yaml` | Staging overrides (environment, project ID, SA names, SA emails, ingress domain/IP name) | Committed in repo |
| `helm/values-production.yaml` | Production overrides (environment, project ID, SA names, SA emails, ingress domain/IP name) | Committed in repo |
| `helm/values-dynamic.yaml` | Dynamic values (app version only) | Generated by CI at build time — **not committed** |

### Values Hierarchy (merged in order by Skaffold):

```
values.yaml → values-<env>.yaml → values-dynamic.yaml
```

Later files override earlier ones. Keys in `values-dynamic.yaml` override the same keys in `values-<env>.yaml`.

### Key Values

| Helm Value | Set In | Example |
|------------|--------|---------|
| `replicaCount` | `values.yaml` | `2` |
| `service.type` | `values.yaml` | `NodePort` |
| `service.port` | `values.yaml` | `80` |
| `service.targetPort` | `values.yaml` | `8080` |
| `ingress.enabled` | `values.yaml` | `true` |
| `ingress.domain` | `values-<env>.yaml` | `gcp-clouddeploy-gke-template.demo.devops-for-hire.com` |
| `ingress.staticIPName` | `values-<env>.yaml` | `gcp-clouddeploy-gke-template-prod-lb-ip` |
| `serviceAccount.name` | `values-<env>.yaml` | `gcp-clouddeploy-gke-template-prod` |
| `serviceAccount.gcpServiceAccount` | `values-<env>.yaml` | `gke-tpl-production@dfh-prod-id.iam.gserviceaccount.com` |
| `app.environment` | `values-<env>.yaml` | `production` |
| `app.projectId` | `values-<env>.yaml` | `dfh-prod-id` |
| `app.firestoreDatabaseName` | `values-<env>.yaml` | `gcp-clouddeploy-gke-template` |
| `app.version` | `values-dynamic.yaml` | `v1.0.14` |
| `app.port` | `values.yaml` | `"8080"` |

### Image Substitution

The container image is **not** set via Helm values. The Helm deployment template uses:
```yaml
image: gcp-clouddeploy-gke-template
```
Skaffold replaces this with the actual Artifact Registry image URI via the `--images` flag during Cloud Deploy rendering:
```
--images=gcp-clouddeploy-gke-template=us-central1-docker.pkg.dev/<project>/gcp-clouddeploy-gke-template/gcp-clouddeploy-gke-template:v1.0.14
```

### Templates

| Template | Description |
|----------|-------------|
| `helm/templates/deployment.yaml` | Deployment with Helm-templated env vars, health probes, resource limits, `runAsNonRoot` security context |
| `helm/templates/service.yaml` | NodePort Service — external traffic is routed through the Ingress, not directly via LoadBalancer |
| `helm/templates/service-account.yaml` | K8s ServiceAccount with Workload Identity GCP SA annotation |
| `helm/templates/ingress.yaml` | GKE Ingress with global static IP annotation, managed SSL certificate reference, and FrontendConfig reference |
| `helm/templates/managed-certificate.yaml` | Google-managed SSL certificate — auto-provisioned and renewed for the custom domain |
| `helm/templates/frontend-config.yaml` | HTTP-to-HTTPS redirect (301) — ensures all traffic uses HTTPS |

---

## Cloud Deploy

### Pipeline Architecture

Cloud Deploy manages progressive delivery with per-environment targets:

| Target | GKE Cluster | Triggered By |
|--------|-------------|-------------|
| **staging** | GKE cluster in `dfh-stage-id` | GitHub Actions creates a Cloud Deploy release (stage branch) |
| **production** | GKE cluster in `dfh-prod-id` | GitHub Actions creates a Cloud Deploy release (main branch) |

Each environment has its own Cloud Deploy pipeline with a single target, keeping staging and production fully isolated in separate GCP projects.

### Skaffold Integration

Cloud Deploy uses Skaffold for rendering Kubernetes manifests:
- `skaffold.yaml` at repo root defines the deploy configuration
- Uses **Helm deployer** (not kubectl) to render templates from `helm/`
- Profiles select the correct values files per environment:
  - `staging` profile: `helm/values-staging.yaml` + `helm/values-dynamic.yaml`
  - `production` profile: `helm/values-production.yaml` + `helm/values-dynamic.yaml`
- Image substitution replaces the `gcp-clouddeploy-gke-template` placeholder with the actual Artifact Registry image

### Release Naming

Release names follow the format `rel-v<VERSION>-<SHORT_SHA>` (e.g., `rel-v1-0-14-23e5a3b`). This keeps rollout IDs under the 63-character limit imposed by GCP.

### Cloud Deploy Target Naming

Target names use `var.cluster_name` (e.g., `gcp-clouddeploy-gke-tpl-prod`) instead of the longer `service_name-environment` to keep rollout resource IDs within GCP's 63-character limit.

### Deployment Flow

```
git push (matching paths) → GitHub Actions:
  1. test (Go test, vet, lint)
  2. build-and-deploy:
     a. Terraform apply (GKE, Cloud Deploy, static IP, DNS, etc.)
     b. Docker build + push to Artifact Registry
     c. Generate helm/values-dynamic.yaml (version only — static IP is referenced by name in committed values files)
     d. gcloud deploy releases create with --source=. (Skaffold + Helm render → deploy to GKE)
     e. Wait for rollout + smoke test
```

---

## Terraform Infrastructure

### Provider & State

- **Provider:** `hashicorp/google ~> 5.0`
- **Required Terraform:** `>= 1.0`
- **Remote state:** GCS bucket per environment (configured in `<env>/backend.tf`)
- **State prefix:** `gcp-clouddeploy-gke-template/state`

### Resources Created

| Resource | File | Description |
|----------|------|-------------|
| `google_container_cluster` | `gke.tf` | GKE Autopilot cluster (`deletion_protection = false`) |
| `google_artifact_registry_repository` | `artifact-registry.tf` | Docker repository for container images |
| `google_compute_global_address` | `dns.tf` | Global static IP for the GKE Ingress (MUST be global, not regional — required by GKE Ingress) |
| `google_dns_record_set` | `dns.tf` | A record in Cloud DNS (cross-project in `dfh-ops-id`) pointing to the global static IP |
| `google_service_account` (runtime) | `iam.tf` | Runtime SA for GKE workloads with logging + Firestore roles |
| `google_service_account_iam_member` | `iam.tf` | Workload Identity binding (K8s SA → GCP SA) |
| `google_service_account` (clouddeploy execution) | `clouddeploy.tf` | Cloud Deploy execution SA with GKE + AR + storage + logging permissions |
| `google_project_iam_member` (various) | `iam.tf`, `clouddeploy.tf` | Role bindings for runtime and Cloud Deploy execution SAs |
| `google_clouddeploy_delivery_pipeline` | `clouddeploy.tf` | Cloud Deploy pipeline with target |
| `google_clouddeploy_target` | `clouddeploy.tf` | Cloud Deploy GKE target (name = `var.cluster_name`) |
| `google_firestore_database` | `firestore.tf` | Firestore Native mode database |
| `google_firestore_document` | `firestore.tf` | Seed document `greetings/hello` with `{"message": "Hello World!"}` |
| `google_project_service` | `apis.tf` | Enables required GCP APIs |

### Terraform Outputs

| Output | Description |
|--------|-------------|
| `cluster_endpoint` | GKE cluster endpoint |
| `cluster_name` | GKE cluster name |
| `service_account_email` | Runtime SA email |
| `clouddeploy_pipeline_name` | Cloud Deploy pipeline name |
| `gke_lb_ip` | Global static IP address reserved for the GKE Ingress |
| `gke_lb_ip_name` | Name of the global static IP resource (used in the Ingress annotation `kubernetes.io/ingress.global-static-ip-name`) |

### GKE Configuration

- **Cluster type:** Autopilot (Google manages node pools, scaling, and upgrades)
- **Location:** Configurable region (default: `us-central1`)
- **Networking:** VPC-native with default network
- **Workload Identity:** Enabled for secure pod-to-GCP-service authentication
- **Deletion protection:** Disabled (`deletion_protection = false`) to allow Terraform lifecycle management

### Terraform Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID (required) |
| `region` | string | `us-central1` | GCP region |
| `service_name` | string | — | Application/service name (required) |
| `environment` | string | — | Environment name: staging/production (required) |
| `image_tag` | string | `latest` | Docker image tag |
| `cluster_name` | string | — | GKE cluster name (required) |
| `tfstate_bucket_name` | string | — | GCS bucket for Terraform state (required) |
| `deploy_sa_email` | string | `""` | Deploy SA email (optional) |
| `dns_project_id` | string | — | GCP project where Cloud DNS zone is managed (required) |
| `dns_zone_name` | string | — | Cloud DNS managed zone name (required) |
| `dns_domain` | string | — | Base DNS domain, e.g., `demo.devops-for-hire.com` (required) |
| `custom_domain` | string | — | Full custom domain for the service (required) |
| `firestore_database_name` | string | — | Firestore database name (required) |
| `firestore_location` | string | `nam5` | Firestore database location |
| `ar_repository_name` | string | — | Artifact Registry repository name (required) |

### Environments

| Environment | GCP Project    | Branch   | Terraform Config    | State Bucket         | Cluster Name                        | Custom Domain |
|-------------|----------------|----------|---------------------|----------------------|-------------------------------------|---------------|
| Staging     | `dfh-stage-id` | `stage`  | `terraform/stage/`  | `dfh-stage-tfstate`  | `gcp-clouddeploy-gke-tpl-stage`     | `gcp-clouddeploy-gke-template.stage.demo.devops-for-hire.com` |
| Production  | `dfh-prod-id`  | `main`   | `terraform/prod/`   | `dfh-prod-tfstate`   | `gcp-clouddeploy-gke-tpl-prod`      | `gcp-clouddeploy-gke-template.demo.devops-for-hire.com` |

---

## CI/CD Pipeline

### Overview

This template uses GitHub Actions for the entire CI/CD pipeline. GitHub Actions handles testing, building, infrastructure provisioning (Terraform), Helm values injection, and deployment (Cloud Deploy release creation).

| Concern | Tool | Description |
|---------|------|-------------|
| **Testing** | GitHub Actions | Runs Go tests, vet, and lint |
| **Building** | GitHub Actions | Builds Docker image, pushes to Artifact Registry |
| **Infrastructure** | GitHub Actions + Terraform | Creates/updates GKE cluster, Cloud Deploy pipeline, static IP, DNS, Firestore, IAM |
| **Helm values** | GitHub Actions | Generates `helm/values-dynamic.yaml` with version only (static IP is referenced by name in committed values files) |
| **Deploying** | GitHub Actions + Cloud Deploy | Creates a Cloud Deploy release (Skaffold + Helm render), which rolls out to GKE target |

### Workflow: `.github/workflows/main.yml`

Single workflow file with path-filtered triggers, `workflow_dispatch`, and branch-based environment determination.

**Triggers:**
- **Push** to `main` or `stage` — only when paths match: `service/**`, `helm/**`, `terraform/**`, `skaffold.yaml`, `VERSION`
- **Pull request** to `main` or `stage` — runs test job only
- **Manual `workflow_dispatch`** — runs full pipeline with environment selector (prod/stage)

**Files that do NOT trigger a deploy:** `scripts/`, `*.md`, `.github/workflows/`, `.gitignore`, etc.

### Job 1: `test` (runs on all triggers)

| Step | Tool | Description |
|------|------|-------------|
| Checkout | `actions/checkout@v5` | Clone repo |
| Set up Go | `actions/setup-go@v5` | Go 1.21 |
| Cache modules | `actions/cache@v4` | Cache `~/go/pkg/mod` |
| Install deps | `go mod download` | In `./service` |
| Run tests | `go test ./...` | In `./service` |
| Run vet | `go vet ./...` | In `./service` |
| Lint | `golangci/golangci-lint-action@v7` | Latest version |

### Job 2: `build-and-deploy` (push + workflow_dispatch only, not PRs)

**Condition:** `(push AND branch is main/stage) OR workflow_dispatch`

**Environment determination:**

| Trigger | `ENV_NAME` | `PROJECT_ID` |
|---------|------------|--------------|
| Push to `main` | `prod` | `dfh-prod-id` |
| Push to `stage` | `stage` | `dfh-stage-id` |
| `workflow_dispatch` with `environment=prod` | `prod` | `dfh-prod-id` |
| `workflow_dispatch` with `environment=stage` | `stage` | `dfh-stage-id` |

**Steps:**
1. Checkout (full history for commit count)
2. Determine environment from branch or `workflow_dispatch` input
3. Authenticate to GCP (two conditional steps — one for staging, one for production — to avoid the GitHub Actions ternary expression bug where `${{ A && B || C }}` is not a true ternary)
4. Set up gcloud CLI
5. Set up Terraform 1.5.0
6. Compute version: `<MAJOR.MINOR from VERSION file>.<commit_count>` (e.g., `1.0.14`)
7. **Terraform apply** — provisions GKE, Cloud Deploy, global static IP, DNS, etc.
8. Configure Docker for Artifact Registry (`us-central1-docker.pkg.dev`)
9. Build Docker image with version tag + `latest`
10. Push both tags to Artifact Registry
11. **Generate `helm/values-dynamic.yaml`** — writes `app.version` only (the static IP is referenced by name in the committed per-environment values files, not by address)
12. **Create Cloud Deploy release** via `gcloud deploy releases create` with `--images` and `--source=.` flags
13. Install GKE auth plugin, wait for rollout, get cluster credentials, run smoke test (`kubectl rollout status` + `curl https://<domain>/health`)
14. Notify deployment result

### Cloud Deploy Pipeline

Each environment has its own Cloud Deploy delivery pipeline with a single GKE target:

- **Staging pipeline:** `gcp-clouddeploy-gke-template-stage-pipeline` → GKE cluster in `dfh-stage-id`
- **Production pipeline:** `gcp-clouddeploy-gke-template-prod-pipeline` → GKE cluster in `dfh-prod-id`

Releases are created by GitHub Actions after a successful image push and Terraform apply.

### Required GitHub Secrets

| Secret | Description | Used For |
|--------|-------------|----------|
| `GCP_STAGE_SA_KEY` | JSON key for deploy SA in `dfh-stage-id` | Terraform apply + GCP auth for staging |
| `GCP_PROD_SA_KEY`  | JSON key for deploy SA in `dfh-prod-id`  | Terraform apply + GCP auth for production |

### Service Accounts

There are **three types** of service accounts per environment:

1. **Deploy SA** (`gcp-cloudrun-deploy@<project>.iam.gserviceaccount.com`)
   - Pre-existing in each project
   - Used by GitHub Actions to push images, run Terraform, and create Cloud Deploy releases
   - JSON key stored as a GitHub secret
   - Requires roles: `artifactregistry.admin`, `clouddeploy.admin`, `compute.admin`, `container.admin`, `datastore.owner`, `dns.admin` (on `dfh-ops-id`), `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `logging.logWriter`, `resourcemanager.projectIamAdmin`, `serviceusage.serviceUsageAdmin`, `storage.admin`

2. **Cloud Deploy Execution SA** (`deploy-gke-tpl-<environment>@<project>.iam.gserviceaccount.com`)
   - Created and managed by Terraform (`clouddeploy.tf`)
   - Used by Cloud Deploy to render Helm templates and deploy to GKE
   - Has roles: `container.developer`, `logging.logWriter`, `storage.objectAdmin`, `artifactregistry.reader`

3. **Runtime SA** (`gke-tpl-<environment>@<project>.iam.gserviceaccount.com`)
   - Created and managed by Terraform (`iam.tf`)
   - Used by GKE pods at runtime via Workload Identity
   - Has `roles/logging.logWriter` and `roles/datastore.user`

### Versioning

- `VERSION` file contains `MAJOR.MINOR` (e.g., `1.0`)
- CI/CD appends commit count as patch: `1.0.<commit_count>`
- Docker images tagged as `v<version>` (e.g., `v1.0.14`) and `latest`
- `APP_VERSION` env var is set via Helm `values-dynamic.yaml`

---

## Destroying Infrastructure

Use the destroy script to tear down all cloud resources for an environment:

```bash
./scripts/destroy.sh <prod|stage>
```

**Steps performed:**
1. Deletes Kubernetes workloads (deployment, service, service-account, ingress, managed-certificate, frontend-config) via kubectl
2. Deletes Cloud Deploy releases, delivery pipeline (`--force`), and target
3. Cleans Cloud Deploy artifact buckets in GCS
4. Deletes all Artifact Registry images
5. Runs `terraform destroy` (GKE cluster, Firestore, global static IP, DNS, SAs, IAM bindings)
6. Cleans Cloud Build logs and Cloud Deploy source staging buckets

**Notes:**
- Requires interactive `yes` confirmation
- Idempotent — safe to run multiple times
- Preserves Terraform state bucket and GCP projects
- Cloud Build execution history is immutable (GCP audit trail) and cannot be deleted

---

## Design Decisions

1. **Embedded HTML templates** — Templates live in separate `.html` files, embedded at compile time via Go's `embed` package. The binary is fully self-contained with no external file dependencies.

2. **UI → API pattern** — The web UI fetches content dynamically from the JSON API via `fetch()`. This mirrors real-world frontend-to-backend separation and is ready to extend.

3. **Minimal dependencies** — Only the Go standard library and `cloud.google.com/go/firestore` are used. The Firestore SDK is the sole external dependency, added for the persistence layer.

4. **Pre-parsed template** — The HTML template is parsed once at server construction time (`server.New()`), not on every request.

5. **Alpine runtime with numeric UID** — Small image with shell access for debugging. Runs as non-root user `rdapp` with numeric UID 1001 (`USER 1001`), which is required for Kubernetes `runAsNonRoot` security context validation.

6. **Graceful shutdown** — Listens for SIGINT/SIGTERM and drains connections with a 10-second timeout, matching Kubernetes pod termination lifecycle.

7. **GitHub Actions + Cloud Deploy** — GitHub Actions handles the full CI/CD pipeline (test, build, push, Terraform, Helm values injection, release creation), while Cloud Deploy handles the actual rollout to GKE via Skaffold + Helm rendering.

8. **Helm chart instead of raw manifests** — Environment-specific values (project IDs, SA names, SA emails, ingress domain, static IP name) are committed in per-environment values files (`values-staging.yaml`, `values-production.yaml`). Only the app version is injected at CI time into a separate `values-dynamic.yaml` file. This avoids `sed` substitutions and keeps manifests clean.

9. **GKE Ingress with HTTPS** — External traffic is routed through a GKE Ingress (not a raw LoadBalancer). Terraform reserves a global static IP (`google_compute_global_address`) that is referenced by NAME in the Ingress annotation (`kubernetes.io/ingress.global-static-ip-name`). A Google-managed SSL certificate (`ManagedCertificate`) auto-provisions HTTPS for the custom domain, and a `FrontendConfig` redirects HTTP to HTTPS. This pattern provides stable DNS, automatic TLS, and HTTPS-by-default. IMPORTANT: GKE Ingress requires a GLOBAL static IP (not regional). The Ingress references the IP by resource name, not by address value.

10. **GKE Autopilot** — Uses Autopilot mode for fully managed node infrastructure. Google handles node scaling, security patches, and resource optimization.

11. **Separate state per environment** — Each environment has its own GCS bucket and Terraform state, preventing cross-environment interference.

12. **Separate GCP projects per environment** — Staging and production are fully isolated in different GCP projects with their own service accounts, clusters, and pipelines.

13. **Structured JSON responses** — All API endpoints return proper JSON with correct `Content-Type` headers and consistent field naming.

14. **Firestore persistence** — The greeting message is stored in Firestore and fetched at request time. Terraform seeds the initial document. The `Store` interface allows easy testing with mocks and swapping implementations.

15. **Graceful Firestore fallback** — If Firestore is unavailable (local dev without `GCP_PROJECT_ID`, or transient errors), the API falls back to a hardcoded `"Hello World!"` message. The service never crashes due to a database issue.

16. **Workload Identity** — GKE pods authenticate to GCP services (Firestore) using Workload Identity rather than JSON key files, following GCP security best practices.

17. **Path-filtered CI/CD triggers** — Deploy only runs when app code (`service/`), Helm chart (`helm/`), Terraform (`terraform/`), or deploy config (`skaffold.yaml`, `VERSION`) changes. Documentation, scripts, and workflow file changes do not trigger a deploy. Manual `workflow_dispatch` is available for on-demand deploys. Note: `Dockerfile` is not listed separately because it lives at `service/Dockerfile` and is already covered by `service/**`.

18. **Deletion protection disabled** — GKE clusters have `deletion_protection = false` to allow Terraform to manage the full lifecycle including destruction. The destroy script handles cleanup in the correct dependency order.

19. **Split GCP auth steps in CI** — GitHub Actions authenticates to GCP using two conditional steps (one for staging, one for production) instead of a single step with a ternary expression. The GitHub Actions expression `${{ A && B || C }}` is NOT a true ternary — if `B` is falsy (e.g., the secret is empty), it falls through to `C`. Splitting into two steps prevents accidental cross-environment authentication.

20. **Cloud Deploy `--source=.` flag** — The `gcloud deploy releases create` command includes `--source=.` to explicitly upload the Helm chart and values files for Cloud Deploy to render via Skaffold. Without this flag, Cloud Deploy may fail to find the source files.

21. **GKE auth plugin in CI** — The CI smoke test step installs `google-cloud-sdk-gke-gcloud-auth-plugin` before running `kubectl` commands. This plugin is required for `kubectl` to authenticate to GKE clusters on GitHub Actions runners.
