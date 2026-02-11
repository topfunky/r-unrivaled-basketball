# Buildkite Migration

Migration from GitHub Actions to Buildkite for the
`r-unrivaled-basketball` project.

## Workflow Mapping

| GitHub Actions Workflow       | Buildkite Pipeline File              |
|-------------------------------|--------------------------------------|
| `.github/workflows/validate.yml` | `.buildkite/pipeline.validate.yml` |

## Secrets and Variables

### GitHub Actions Workflow Variables

The `validate.yml` workflow uses the following environment variables.
None are secrets — all are static configuration values.

| Variable            | Source          | Value / Purpose                  |
|---------------------|-----------------|----------------------------------|
| `DEBIAN_FRONTEND`   | Job-level `env` | `noninteractive` — suppresses apt prompts |

No GitHub Actions secrets (`${{ secrets.* }}`) are referenced in
any workflow.

### Buildkite Environment Variables

The following Buildkite-provided environment variables are commonly
available in pipeline steps and may be useful for debugging or
conditional logic.

| Variable                          | Description                              |
|-----------------------------------|------------------------------------------|
| `BUILDKITE`                       | Always `true` inside a Buildkite build   |
| `BUILDKITE_BRANCH`               | Branch being built                       |
| `BUILDKITE_BUILD_NUMBER`         | Incrementing build number                |
| `BUILDKITE_BUILD_URL`            | URL to the build in the Buildkite UI     |
| `BUILDKITE_COMMIT`               | Git commit SHA being built               |
| `BUILDKITE_PIPELINE_SLUG`       | URL-friendly pipeline name               |
| `BUILDKITE_PULL_REQUEST`        | PR number, or `false` if not a PR build  |
| `BUILDKITE_PULL_REQUEST_BASE_BRANCH` | Base branch of the PR              |
| `BUILDKITE_REPO`                 | Repository URL                           |
| `BUILDKITE_STEP_KEY`            | Key of the current step                  |
| `BUILDKITE_TAG`                  | Git tag, if the build was triggered by a tag |

## Agent Requirements

The pipeline requires agents with:

- **OS**: Ubuntu 24.04 (or compatible)
- **Privileges**: `sudo` access for `apt-get` and system-wide R
  configuration
- **Tools**: `wget`, `gnupg`, `ca-certificates`, `make`

### Recommended Agent Setup

For faster builds, pre-install R and dependencies on the agent
image rather than installing them on every build. Consider:

1. A custom Docker image based on `ubuntu:24.04` with R, r2u,
   bspm, and `r-cran-lintr` pre-installed.
2. A custom AMI/VM image with the same pre-installed stack.
3. Using the Buildkite
   [Docker plugin](https://github.com/buildkite-plugins/docker-buildkite-plugin)
   to run steps inside a container.

## Trigger Configuration

Configure the following in the Buildkite UI under
**Pipeline Settings > GitHub**:

- Enable **Build pull requests** (targets `main`)
- Enable **Build branches** (filter to `main`)
- Manual builds are supported via the **New Build** button
  (equivalent to `workflow_dispatch`)

## Notes

- No `.gitignore` changes were needed — the pipeline does not
  produce local artifacts beyond what is already ignored.
- The original workflow had a single job (`validate`) which maps
  to a single Buildkite step with Buildkite section headers
  (`---`) for visual separation in the build log.
