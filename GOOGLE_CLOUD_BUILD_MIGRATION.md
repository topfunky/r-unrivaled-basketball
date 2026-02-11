# Google Cloud Build Migration

This document describes the Cloud Build CI setup for the r-unrivaled-basketball project.
Cloud Build runs alongside existing GitHub Actions, using a custom Docker image with R
and dependencies pre-installed for fast validation and test runs.

## Overview

- **Pipeline:** Build R Docker image → run `make validate` (lintr) → run `make test` (testthat)
- **Triggers:** Push to `main`, pull requests targeting `main`
- **Output:** Linted R code, passing test suite; built image pushed to Artifact Registry

## Prerequisites

- GCP project
- `gcloud` CLI installed and authenticated
- GitHub repository access for Cloud Build

## Files

| File               | Purpose                                          |
|--------------------|--------------------------------------------------|
| `cloudbuild.yaml`  | Cloud Build steps (build image, run validate/test)|
| `docker/Dockerfile`| Custom R image with r2u, bspm, and project deps  |
| `.dockerignore`    | Reduces build context size                        |

## Setup

### 1. Enable APIs

```bash
gcloud services enable cloudbuild.googleapis.com artifactregistry.googleapis.com \
  --project=YOUR_PROJECT_ID
```

### 2. Create Artifact Registry Repository

```bash
gcloud artifacts repositories create r-unrivaled-basketball \
  --repository-format=docker \
  --location=us-central1 \
  --project=YOUR_PROJECT_ID
```

### 3. Grant IAM Permissions

Cloud Build needs permission to push images to Artifact Registry:

```bash
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

### 4. Connect GitHub

1. Open [Cloud Console > Cloud Build > Triggers](https://console.cloud.google.com/cloud-build/triggers)
2. Click "Connect Repository"
3. Select "GitHub (Cloud Build GitHub App)" or "GitHub (Mirror)"
4. Authenticate and choose the `r-unrivaled-basketball` repository
5. Install the Cloud Build GitHub App if prompted

### 5. Create Triggers

**Push trigger**

- **Name:** `validate-on-push`
- **Event:** Push to a branch
- **Source:** Connected GitHub repo
- **Branch:** `^main$`
- **Configuration:** Cloud Build configuration file
- **Location:** Repository
- **File:** `cloudbuild.yaml`

**Pull request trigger**

- **Name:** `validate-on-pr`
- **Event:** Pull request
- **Source:** Connected GitHub repo
- **Branch:** `^main$`
- **Configuration:** Same as push trigger

Substitution variables (`_IMAGE_NAME`, `SHORT_SHA`) are set automatically by Cloud Build
when using the default `cloudbuild.yaml` configuration. No trigger-level substitutions
are required unless you use a different Artifact Registry path or region.

## Manual Builds

Run a build locally or from Cloud Console:

```bash
gcloud builds submit --config=cloudbuild.yaml .
```

From a non-git directory or when `SHORT_SHA` is not set (e.g. triggerless build), pass a
tag explicitly:

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=SHORT_SHA=latest .
```

## Validation

1. Push a commit to `main` and verify a Cloud Build run starts
2. Open a PR targeting `main` and verify a build runs
3. Confirm build logs show successful `make validate` and `make test`
4. Check GitHub status checks on commits and PRs (when using the GitHub App)

## Architecture

**Build stages**

1. **build-image:** Builds the Docker image from `docker/Dockerfile`, tagging it with
   `us-central1-docker.pkg.dev/PROJECT_ID/r-unrivaled-basketball/ci-r:SHORT_SHA`
2. **validate:** Runs the image with source mounted at `/workspace`, executes
   `make validate && make test`
3. **images:** Pushes the built image to Artifact Registry

**Docker image**

- Base: `ubuntu:24.04`
- R installed via r2u and CRAN Apt (Noble)
- bspm for binary package installs
- lintr and project packages from `install_dependencies.R`

Cloud Build mounts the repository at `/workspace` for the validate step, so lint and tests
run against the current commit without rebuilding the image.

## Cost and Limits

- **Free tier:** 120 build-minutes/day
- **Typical run:** ~5–10 minutes depending on layer cache
- **Image caching:** Rebuilds are faster when only app code changes; changes to
  `docker/Dockerfile` or `install_dependencies.R` invalidate more layers

## Troubleshooting

**Build fails on package install**

- Ensure `install_dependencies.R` and `Makefile` are unchanged and present at repo root
- Check that CRAN and r2u repositories are reachable from Cloud Build

**Image push denied**

- Verify the Cloud Build service account has `roles/artifactregistry.writer`
- Ensure the Artifact Registry repository exists in the same project and region

**SHORT_SHA empty**

- `SHORT_SHA` is set by trigger-based builds; for manual `gcloud builds submit`, pass
  `--substitutions=SHORT_SHA=latest` (or another tag)

## Secrets

If future validation steps need secrets (e.g. API keys), use [Secret Manager](https://cloud.google.com/secret-manager) and the `availableSecrets` field in `cloudbuild.yaml`.
