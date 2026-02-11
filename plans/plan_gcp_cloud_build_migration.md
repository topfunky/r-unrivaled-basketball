# Plan: GCP Cloud Build Migration

Add Google Cloud Build as a parallel CI system alongside existing GitHub Actions.
Use a custom Docker image with R and dependencies pre-installed for fast builds.
Trigger on pushes to main and pull requests via GitHub integration.

## Prerequisites

- GCP project exists
- `gcloud` CLI installed and authenticated
- GitHub repository access for Cloud Build connection

## Phase 1: GCP Setup

### 1.1 Enable Cloud Build API

```bash
gcloud services enable cloudbuild.googleapis.com --project=YOUR_PROJECT_ID
```

### 1.2 Enable Artifact Registry (for custom Docker images)

```bash
gcloud services enable artifactregistry.googleapis.com --project=YOUR_PROJECT_ID
```

### 1.3 Create Artifact Registry repository

```bash
gcloud artifacts repositories create r-unrivaled-basketball \
  --repository-format=docker \
  --location=us-central1 \
  --project=YOUR_PROJECT_ID
```

## Phase 2: Custom Docker Image

### 2.1 Create Dockerfile

Create `docker/Dockerfile` (or `Dockerfile` in repo root) that:

1. Uses `ubuntu:24.04` as base
2. Adds r2u and CRAN Apt repositories (same logic as `.buildkite/scripts/validate.sh`)
3. Installs `r-base-core`, `python3-dbus`, `python3-gi`, `python3-apt`, `r-cran-lintr`
4. Installs bspm and enables it in Rprofile.site
5. Runs `make install-deps` to install project R packages (requires copying repo context)
6. Installs `make` and `wget` (for checkout and make commands)

Note: The Dockerfile must copy the repo (or a minimal subset) before `make
install-deps` since that reads `install_dependencies.R`. Options:

- Build image as part of Cloud Build (build step copies source first)
- Use a two-stage Cloud Build: first build image, then run validation

### 2.2 Recommended approach: Two-stage Cloud Build

**Stage 1 (build image):** A Cloud Build step that builds the Docker image with R,
r2u, bspm, and lintr. Project packages (tidyverse, testthat, etc.) are installed at
runtime in the validate step to avoid rebuilding the image when `install_dependencies.R`
changes.

**Alternative:** Install all project packages in the image for maximum speed. Rebuild
image when `install_dependencies.R` changes. Use a separate "build image" trigger
or manual build for that.

For this plan, assume we use the faster variant: full image with project packages,
rebuilt when `install_dependencies.R` or `docker/Dockerfile` changes.

## Phase 3: Cloud Build Configuration

### 3.1 Create `cloudbuild.yaml` in repo root

```yaml
# Cloud Build configuration for R validation and tests
# Runs validate + test using custom R image

steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_IMAGE_NAME}:${SHORT_SHA}'
      - '-f'
      - 'docker/Dockerfile'
      - '.'
    id: 'build-image'

  - name: '${_IMAGE_NAME}:${SHORT_SHA}'
    id: 'validate'
    env:
      - 'DEBIAN_FRONTEND=noninteractive'
    args:
      - 'bash'
      - '-c'
      - 'make validate && make test'
    waitFor: ['build-image']

images:
  - '${_IMAGE_NAME}:${SHORT_SHA}'

options:
  logging: CLOUD_LOGGING_ONLY
```

Substitution variables (`_IMAGE_NAME`) are set in the trigger. Example:
`us-central1-docker.pkg.dev/PROJECT_ID/r-unrivaled-basketball/ci-r`.

### 3.2 Or: Use pre-built image for speed

If the image is built separately (e.g., weekly or on Dockerfile change), the main
`cloudbuild.yaml` can pull the image and only run validate + test:

```yaml
steps:
  - name: 'us-central1-docker.pkg.dev/PROJECT_ID/r-unrivaled-basketball/ci-r:latest'
    entrypoint: 'bash'
    args:
      - '-c'
      - 'make validate && make test'
    env:
      - 'DEBIAN_FRONTEND=noninteractive'
```

This reduces build time but requires a process to keep the image updated.

## Phase 4: Dockerfile Content

Create `docker/Dockerfile` with steps mirroring `.buildkite/scripts/validate.sh`:

1. `FROM ubuntu:24.04`
2. `ENV DEBIAN_FRONTEND=noninteractive`
3. Install wget, ca-certificates, gnupg
4. Add r2u GPG key and repository
5. Add CRAN GPG key and repository
6. Add apt preferences for r2u
7. `apt-get update && apt-get install -y r-base-core python3-dbus python3-gi python3-apt r-cran-lintr make`
8. Install bspm and configure Rprofile.site
9. Copy `install_dependencies.R` and `Makefile`, run `make install-deps`
10. Copy full repo (or necessary R files) for lint/tests

The Dockerfile must be structured so `make install-deps` can run (needs
`install_dependencies.R`). Copy order: install deps first, then rest of repo.

## Phase 5: GitHub Integration

### 5.1 Connect GitHub to Cloud Build

1. Open [Cloud Console > Cloud Build > Triggers](https://console.cloud.google.com/cloud-build/triggers)
2. Click "Connect Repository"
3. Select "GitHub (Cloud Build GitHub App)" or "GitHub (Mirror)"
4. Authenticate and choose the `r-unrivaled-basketball` repository
5. For first-time setup, install the Cloud Build GitHub App if prompted

### 5.2 Create push trigger

- **Name:** `validate-on-push`
- **Event:** Push to a branch
- **Source:** GitHub repo
- **Branch:** `^main$`
- **Configuration:** Cloud Build configuration file
- **Location:** Repository
- **File:** `cloudbuild.yaml`
- **Substitution variables:** `_IMAGE_NAME` = `us-central1-docker.pkg.dev/PROJECT_ID/r-unrivaled-basketball/ci-r`

### 5.3 Create pull request trigger

- **Name:** `validate-on-pr`
- **Event:** Pull request
- **Source:** GitHub repo
- **Branch:** `^main$`
- **Configuration:** Same as push trigger
- **Substitution variables:** Same as push trigger

## Phase 6: IAM and Permissions

Cloud Build needs permission to push images to Artifact Registry:

```bash
# Grant Cloud Build service account Artifact Registry Writer
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

## Phase 7: Files to Create

| File               | Purpose                                           |
|--------------------|---------------------------------------------------|
| `docker/Dockerfile`| Custom R image with r2u, bspm, deps               |
| `cloudbuild.yaml`  | Cloud Build steps (build image, run validate+test)|

## Phase 8: Validation

1. Push a commit to `main` and confirm a Cloud Build run starts
2. Open a PR targeting `main` and confirm a build runs
3. Check build logs for `make validate` and `make test` success
4. Compare run time vs. GitHub Actions (target: under 3 minutes with cached image)

## Considerations

- **Image caching:** Cloud Build caches Docker layers. Rebuilds are faster when
  only app code changes, not Dockerfile or `install_dependencies.R`.
- **Cost:** Cloud Build offers 120 build-minutes/day free. Typical run ~5–10 min;
  staying under daily free tier depends on frequency.
- **Secrets:** If validation ever needs secrets, use Secret Manager and
  `availableSecrets` in `cloudbuild.yaml`.
- **GitHub status:** Cloud Build will report status on commits and PRs when
  connected via the GitHub App.
