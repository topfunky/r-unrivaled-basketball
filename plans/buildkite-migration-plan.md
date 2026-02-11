# Buildkite Migration Plan

## Scope
- Full rollout plan for all workflows in `.github/workflows/`.
- Use `bk` for conversion where possible; allow partial conversion and
  annotate TODOs for manual follow-up.
- Create one Buildkite pipeline file per workflow in `.buildkite/`.
- Update `.gitignore` as needed for Buildkite artifacts.
- Document both detected workflow secrets/variables and common Buildkite
  environment variables.

## Assumptions
- Current workflows live under `.github/workflows/`.
- Buildkite configuration will live in `.buildkite/` with one file per
  workflow.

## Steps
1. Inventory existing GitHub Actions workflows.
2. For each workflow, run `bk` conversion and review output.
3. When `bk` output is partial, add TODOs for manual translation and list
   any unsupported features.
4. Create Buildkite pipeline files in `.buildkite/` (one per workflow).
5. Update `.gitignore` for any Buildkite artifacts introduced by the new
   pipelines.
6. Draft `BUILDKITE_MIGRATION.md`:
   - List secrets and variables used in workflows and corresponding
     Buildkite env vars.
   - Include common Buildkite env vars referenced by the pipelines.
   - Exclude any secret values.

## Validation
- Ensure each pipeline has a corresponding Buildkite file.
- Confirm variables and secrets are documented without values.
