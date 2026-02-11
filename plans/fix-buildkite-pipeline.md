# Fix Buildkite Pipeline - Ubuntu Version Mismatch

## Problem

Build #3 fails with exit status 100 at the `apt-get install -y r-base-core` step. The error is:

```
r-base-core : Depends: libc6 (>= 2.38) but 2.35-0ubuntu3.9 is to be installed
              Depends: libcurl4t64 (>= 7.28.0) but it is not installable
              ...
```

**Root cause**: The `pipeline.yml` sets `image: "ubuntu:24.04"` as a top-level key, but this is not a valid Buildkite pipeline configuration key. It is silently ignored. The Buildkite agent runs on Ubuntu 22.04 (Jammy), but the `validate.sh` script configures APT repositories for Ubuntu 24.04 (Noble). The Noble packages require newer system libraries than Jammy provides.

## Solution

Use the Buildkite Docker plugin to run the step inside an `ubuntu:24.04` container. This ensures the OS matches the repository configuration in `validate.sh`.

### Changes

1. **`.buildkite/pipeline.yml`**: Remove the invalid top-level `image` key. Add the `docker` plugin to the validate step so it runs inside `ubuntu:24.04`.

The updated step will look like:

```yaml
steps:
  - label: ":test_tube: Validate R Code"
    key: "validate"
    agents:
      queue: "buildkite-queue"
    command: .buildkite/scripts/validate.sh
    plugins:
      - docker#v5.12.0:
          image: "ubuntu:24.04"
```

No changes needed to `validate.sh` since the script is correct for Noble.
