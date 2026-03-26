# gcp-clouddeploy-gke-template Architecture

> **For AI/LLM agents:** This document is the authoritative reference for this codebase.
> When building a new project from this template, read this file first, then follow
> the step-by-step instructions in [README.md](README.md).

---

## Overview

A production-ready Go HTTP service template deployed to Google Kubernetes Engine (GKE) via Cloud Build and Cloud Deploy with multi-environment CI/CD. It provides:

- A **Web UI** (Go `html/template` with embedded HTML/CSS/JS) that dynamically fetches content from the API
- A **JSON API** with health check and application endpoints
- A **Firestore persistence layer** for storing and fetching dynamic content
- **Terraform** infrastructure-as-code for GKE, Cloud Deploy, Artifact Registry, Firestore, and IAM provisioning
- **Cloud Build** for building Docker images and triggering deployments
- **Cloud Deploy** for progressive delivery to staging and production GKE clusters
- **GitHub Actions** CI/CD for running tests on push/PR (build and deploy handled by Cloud Build + Cloud Deploy)

This repo is designed to be cloned and adapted for new Web UI / Go API / GKE projects.

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
├── k8s/                               # Kubernetes manifests
│   ├── deployment.yaml                # Deployment with env vars, health probes, resource limits
│   └── service.yaml                   # LoadBalancer Service exposing port 80 → 8080
│
├── cloudbuild.yaml                    # Cloud Build config: build image → push to AR → create Cloud Deploy release
├── skaffold.yaml                      # Skaffold config for Cloud Deploy rendering
│
├── terraform/                         # Shared Terraform modules (used by all environments)
│   ├── main.tf                        # Google Cloud provider configuration
│   ├── variables.tf                   # Input variables (project_id, region, cluster_name, etc.)
│   ├── versions.tf                    # Terraform >= 1.0, google provider ~> 5.0
│   ├── gke.tf                         # GKE Autopilot cluster + node config
│   ├── iam.tf                         # Runtime SA, Cloud Build SA roles, Cloud Deploy SA roles
│   ├── dns.tf                         # A record in Cloud DNS pointing to GKE ingress IP
│   ├── firestore.tf                   # Firestore database + seed greeting document
│   ├── apis.tf                        # Enables required GCP APIs
│   ├── artifact-registry.tf           # Artifact Registry Docker repository
│   ├── cloudbuild.tf                  # Cloud Build trigger (connected to GitHub repo)
│   ├── clouddeploy.tf                 # Cloud Deploy pipeline + stage/prod targets
│   ├── outputs.tf                     # Outputs: cluster_endpoint, service_account_email, etc.
│   ├── stage/
│   │   ├── backend.tf                 # GCS backend: bucket=dfh-stage-tfstate
│   │   └── stage.tfvars               # project_id=dfh-stage-id, cluster config
│   └── prod/
│       ├── backend.tf                 # GCS backend: bucket=dfh-prod-tfstate
│       └── prod.tfvars                # project_id=dfh-prod-id, cluster config
│
└── .github/
    └── workflows/
        └── main.yml                   # Test workflow: runs Go tests on push/PR
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
  adduser rdapp (non-root)
  COPY --from=builder /app/gcp-clouddeploy-gke-template .
  EXPOSE 8080
  HEALTHCHECK wget -qO- http://localhost:8080/health
  CMD ["./gcp-clouddeploy-gke-template"]
```

**Key points:**
- Static binary with `CGO_ENABLED=0` — no C dependencies
- Non-root user `rdapp` for security
- Built-in Docker HEALTHCHECK on `/health`
- Alpine runtime for small image with shell access for debugging

---

## Kubernetes Manifests

### `k8s/deployment.yaml`

- Deploys the container image from Artifact Registry
- Sets environment variables: `ENVIRONMENT`, `APP_VERSION`, `GCP_PROJECT_ID`, `FIRESTORE_DATABASE_NAME`
- Configures liveness and readiness probes on `/health`
- Resource requests and limits for CPU and memory
- Runs as non-root user (security context)
- Image tag is a placeholder (`IMAGE_TAG`) substituted by Cloud Deploy/Skaffold at deploy time

### `k8s/service.yaml`

- Kubernetes `LoadBalancer` Service exposing port 80 → container port 8080
- Provides an external IP for accessing the service

---

## Cloud Build

### `cloudbuild.yaml`

Cloud Build is triggered by pushes to `main` or `stage` branches (configured via Terraform Cloud Build trigger). The build pipeline:

1. **Compute version** — reads `VERSION` file + commit count to produce `MAJOR.MINOR.PATCH`
2. **Build Docker image** — multi-stage build, tagged with version and `latest`
3. **Push to Artifact Registry** — pushes both tags to the project's AR Docker repo
4. **Create Cloud Deploy release** — triggers a release on the Cloud Deploy pipeline, which rolls out to the appropriate GKE target

```
git push → Cloud Build trigger → build image → push to AR → create Cloud Deploy release → deploy to GKE
```

---

## Cloud Deploy

### Pipeline Architecture

Cloud Deploy manages progressive delivery with two targets:

| Target | GKE Cluster | Triggered By |
|--------|-------------|-------------|
| **staging** | GKE cluster in `dfh-stage-id` | Automatic on release creation (from stage branch build) |
| **production** | GKE cluster in `dfh-prod-id` | Automatic on release creation (from main branch build) |

Each environment has its own Cloud Deploy pipeline with a single target, keeping staging and production fully isolated in separate GCP projects.

### Skaffold Integration

Cloud Deploy uses Skaffold for rendering Kubernetes manifests:
- `skaffold.yaml` at repo root defines the deploy configuration
- Uses `kubectl` deployer to apply manifests from `k8s/`
- Image substitution replaces the placeholder image reference with the actual Artifact Registry image

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
| `google_container_cluster` | `gke.tf` | GKE Autopilot cluster |
| `google_artifact_registry_repository` | `artifact-registry.tf` | Docker repository for container images |
| `google_service_account` (runtime) | `iam.tf` | Runtime SA for GKE workloads with logging + Firestore roles |
| `google_service_account` (cloudbuild) | `iam.tf` | Cloud Build SA with build, deploy, and GKE permissions |
| `google_project_iam_member` (various) | `iam.tf` | Role bindings for runtime and Cloud Build SAs |
| `google_cloudbuild_trigger` | `cloudbuild.tf` | Cloud Build trigger connected to GitHub repo |
| `google_clouddeploy_delivery_pipeline` | `clouddeploy.tf` | Cloud Deploy pipeline with target |
| `google_clouddeploy_target` | `clouddeploy.tf` | Cloud Deploy GKE target |
| `google_firestore_database` | `firestore.tf` | Firestore Native mode database |
| `google_firestore_document` | `firestore.tf` | Seed document `greetings/hello` with `{"message": "Hello World!"}` |
| `google_project_service` | `apis.tf` | Enables required GCP APIs |
| `google_dns_record_set` | `dns.tf` | A record in Cloud DNS pointing to GKE service external IP |

### GKE Configuration

- **Cluster type:** Autopilot (Google manages node pools, scaling, and upgrades)
- **Location:** Configurable region (default: `us-central1`)
- **Networking:** VPC-native with default network
- **Workload Identity:** Enabled for secure pod-to-GCP-service authentication

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
| `github_repo_owner` | string | — | GitHub repo owner for Cloud Build trigger (required) |
| `github_repo_name` | string | — | GitHub repo name for Cloud Build trigger (required) |
| `branch_name` | string | — | Branch name that triggers Cloud Build (required) |
| `ar_repository_name` | string | — | Artifact Registry repository name (required) |

### Environments

| Environment | GCP Project    | Branch   | Terraform Config    | State Bucket         | Cluster Name                        | Custom Domain | 
|-------------|----------------|----------|---------------------|----------------------|-------------------------------------|---------------|
| Staging     | `dfh-stage-id` | `stage`  | `terraform/stage/`  | `dfh-stage-tfstate`  | `gcp-clouddeploy-gke-tpl-stage`     | `gcp-clouddeploy-gke-template.stage.demo.devops-for-hire.com` |
| Production  | `dfh-prod-id`  | `main`   | `terraform/prod/`   | `dfh-prod-tfstate`   | `gcp-clouddeploy-gke-tpl-prod`      | `gcp-clouddeploy-gke-template.demo.devops-for-hire.com` |

---

## CI/CD Pipeline

### Overview

Unlike the Cloud Run template (which uses GitHub Actions for the entire build-and-deploy pipeline), this template splits responsibilities:

| Concern | Tool | Description |
|---------|------|-------------|
| **Testing** | GitHub Actions | Runs Go tests, vet, and lint on push/PR |
| **Building** | Cloud Build | Builds Docker image, pushes to Artifact Registry |
| **Deploying** | Cloud Deploy | Creates a release, rolls out to GKE target |

### GitHub Actions Workflow: `.github/workflows/main.yml`

Single workflow for running tests only. Build and deploy are handled entirely by Cloud Build + Cloud Deploy.

**Triggers:**
- Push to `main` or `stage`
- Pull request to `main` or `stage`

**Job: `test`**

| Step | Tool | Description |
|------|------|-------------|
| Checkout | `actions/checkout@v4` | Clone repo |
| Set up Go | `actions/setup-go@v4` | Go 1.21 |
| Cache modules | `actions/cache@v3` | Cache `~/go/pkg/mod` |
| Install deps | `go mod download` | In `./service` |
| Run tests | `go test ./...` | In `./service` |
| Run vet | `go vet ./...` | In `./service` |
| Lint | `golangci/golangci-lint-action@v4` | Latest version |

### Cloud Build Pipeline: `cloudbuild.yaml`

Triggered by Cloud Build trigger (Terraform-managed) on push to the configured branch.

**Steps:**
1. Compute version from `VERSION` file + commit count
2. Build Docker image with version tag + `latest`
3. Push both tags to Artifact Registry
4. Create Cloud Deploy release targeting the environment's pipeline

### Cloud Deploy Pipeline

Each environment has its own Cloud Deploy delivery pipeline with a single GKE target:

- **Staging pipeline:** Targets the staging GKE cluster in `dfh-stage-id`
- **Production pipeline:** Targets the production GKE cluster in `dfh-prod-id`

Releases are created by Cloud Build after a successful image push.

### Required GitHub Secrets

| Secret | Description | Used For |
|--------|-------------|----------|
| `GCP_STAGE_SA_KEY` | JSON key for deploy SA in `dfh-stage-id` | Terraform apply for staging |
| `GCP_PROD_SA_KEY`  | JSON key for deploy SA in `dfh-prod-id`  | Terraform apply for production |

### Service Accounts

There are **three types** of service accounts per environment:

1. **Deploy SA** (`gcp-cloudrun-deploy@<project>.iam.gserviceaccount.com`)
   - Pre-existing in each project
   - Used for Terraform apply (from GitHub Actions or manual)
   - JSON key stored as a GitHub secret
   - Requires roles: `artifactregistry.admin`, `cloudbuild.builds.editor`, `clouddeploy.admin`, `container.admin`, `datastore.owner`, `dns.admin`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `logging.logWriter`, `resourcemanager.projectIamAdmin`, `serviceusage.serviceUsageAdmin`, `storage.admin`

2. **Cloud Build SA** (`cloudbuild-gke-tpl-<environment>@<project>.iam.gserviceaccount.com`)
   - Created and managed by Terraform (`iam.tf`)
   - Used by Cloud Build to build images and create Cloud Deploy releases
   - Has roles: `cloudbuild.builds.builder`, `artifactregistry.writer`, `clouddeploy.releaser`, `logging.logWriter`, `iam.serviceAccountUser`

3. **Runtime SA** (`gke-tpl-<environment>@<project>.iam.gserviceaccount.com`)
   - Created and managed by Terraform (`iam.tf`)
   - Used by GKE pods at runtime via Workload Identity
   - Has `roles/logging.logWriter` and `roles/datastore.user`

### Versioning

- `VERSION` file contains `MAJOR.MINOR` (e.g., `1.0`)
- Cloud Build computes full version: `MAJOR.MINOR.<commit_count>` (e.g., `1.0.42`)
- Docker images tagged as `v<version>` (e.g., `v1.0.42`) and `latest`
- `APP_VERSION` env var is set in the Kubernetes deployment manifest

---

## Design Decisions

1. **Embedded HTML templates** — Templates live in separate `.html` files, embedded at compile time via Go's `embed` package. The binary is fully self-contained with no external file dependencies.

2. **UI → API pattern** — The web UI fetches content dynamically from the JSON API via `fetch()`. This mirrors real-world frontend-to-backend separation and is ready to extend.

3. **Minimal dependencies** — Only the Go standard library and `cloud.google.com/go/firestore` are used. The Firestore SDK is the sole external dependency, added for the persistence layer.

4. **Pre-parsed template** — The HTML template is parsed once at server construction time (`server.New()`), not on every request.

5. **Alpine runtime** — Small image with shell access for debugging. Runs as non-root user `rdapp`.

6. **Graceful shutdown** — Listens for SIGINT/SIGTERM and drains connections with a 10-second timeout, matching Kubernetes pod termination lifecycle.

7. **Cloud Build + Cloud Deploy** — Build and deploy are handled by GCP-native services, not GitHub Actions. This keeps the CI/CD pipeline within GCP, reduces GitHub Actions minutes, and leverages Cloud Deploy's progressive delivery capabilities.

8. **GKE Autopilot** — Uses Autopilot mode for fully managed node infrastructure. Google handles node scaling, security patches, and resource optimization.

9. **Separate state per environment** — Each environment has its own GCS bucket and Terraform state, preventing cross-environment interference.

10. **Separate GCP projects per environment** — Staging and production are fully isolated in different GCP projects with their own service accounts, clusters, and pipelines.

11. **Structured JSON responses** — All API endpoints return proper JSON with correct `Content-Type` headers and consistent field naming.

12. **Firestore persistence** — The greeting message is stored in Firestore and fetched at request time. Terraform seeds the initial document. The `Store` interface allows easy testing with mocks and swapping implementations.

13. **Graceful Firestore fallback** — If Firestore is unavailable (local dev without `GCP_PROJECT_ID`, or transient errors), the API falls back to a hardcoded `"Hello World!"` message. The service never crashes due to a database issue.

14. **Workload Identity** — GKE pods authenticate to GCP services (Firestore) using Workload Identity rather than JSON key files, following GCP security best practices.
