# Plan: PR comment with plots from make all-tasks

## Goal

Improve `.github/workflows/validate.yml` so that on pull requests it posts a comment containing the two 2026 ranking images produced by `make all-tasks`:

- `plots/2026/unrivaled_elo_ratings.png` (from `calculate_elo_ratings.R`)
- `plots/2026/unrivaled_rankings.png` (from `rankings_bump_chart.R`)

## Current state

- **Workflow**: Runs on `workflow_dispatch`, `push` to `main`, and `pull_request` to `main`. Steps: checkout, setup R (r2u + bspm), install deps, `make validate`, `make test`.
- **all-tasks** (Makefile): Runs in order: download, scrape, rankings, elo, standings, pbp, fetch-wnba-stats, shooting. The images we care about are written by:
  - `rankings` → `rankings_bump_chart.R` → `plots/{season_year}/unrivaled_rankings.png`
  - `elo` → `calculate_elo_ratings.R` → `plots/{season_year}/unrivaled_elo_ratings.png`
  So for 2026 the paths are `plots/2026/unrivaled_rankings.png` and `plots/2026/unrivaled_elo_ratings.png`. (You referred to the ELO image as unrivaled_elo_rankings.png; the script actually writes unrivaled_elo_ratings.png.)
- **Data**: Scrape reads from `data/2025/schedule.html` and `data/2026/schedule.html`. Download and fetch_wnba_stats use the network. The repo already has `data/2025/` and `data/2026/` with schedule and CSVs, so in CI we could either run full `make all-tasks` (with network) or a subset; the plan assumes we run full `make all-tasks` so outputs match local runs.

## Constraints

- Comment only when the workflow is triggered by a **pull request** (not on push to main or manual dispatch), so there is a PR to comment on.
- Use only the default `GITHUB_TOKEN` unless we need a secret for image hosting (see below).

## Open decision: how to show the images in the comment

GitHub PR comments support Markdown, but **images must be loaded from a public URL** (`![alt](url)`). GitHub does not expose a way to upload files from Actions and get a URL for use in a comment.

So we have two families of options:

1. **Comment with links only (no inline images)**  
   - Upload the two PNGs as workflow artifacts.  
   - Post a comment with a link to the workflow run and/or “Download artifacts” so reviewers can open the run and download the plots.  
   - **Pros**: No extra services or secrets; only `GITHUB_TOKEN` with default permissions.  
   - **Cons**: Images are not visible inline in the PR.

2. **Comment with inline images**  
   - We need a public URL for each PNG. Possibilities:
   - **A. GitHub Gist**  
     - Create a (possibly throwaway) gist with the two files from the workflow; use the gist raw URLs in the comment body.  
     - **Requires**: A PAT with `gist` scope stored as a repo secret, because the default `GITHUB_TOKEN` does not have gist permissions.
   - **B. External image host (e.g. imgur)**  
     - Upload images via their API and put the returned URLs in the comment.  
     - **Requires**: API key/secret and acceptance of a third-party service.

**Question for you:** Do you want (1) a comment with artifact links only, or (2) inline images? If (2), are you okay adding a repo secret (e.g. PAT with gist scope for option A, or API key for option B)?

## Proposed workflow shape

- Keep the existing **validate** job as-is (same triggers, same steps: checkout, R setup, install-deps, `make validate`, `make test`).
- Add a second job, e.g. **plots**, that:
  - Runs only when the event is `pull_request` (so we have `github.event.pull_request.number` and can post a comment).
  - Depends on **validate** succeeding (so we only run and comment when the repo is in a valid state).
  - Reuses the same runner and R setup (either duplicate the setup steps or extract a reusable workflow; for simplicity we can duplicate in one file).
  - Runs `make all-tasks` (with network; consider a longer timeout if needed).
  - If the two PNGs exist:
    - Uploads them as artifacts (e.g. `plots-2026`) so they are available from the run (paths: `plots/2026/unrivaled_elo_ratings.png`, `plots/2026/unrivaled_rankings.png`).
    - Builds the comment body (either markdown with artifact link(s) or markdown with `![...](url)` if we have image URLs).
    - Posts the comment on the PR (see below).
  - If `make all-tasks` or the plot files are missing, optionally post a short comment or skip commenting (to be decided).

## Comment posting

- Use the Issues API: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments` with `body` = markdown string. The PR number is `github.event.pull_request.number`; for the Issues API, the “issue” number of a PR is the same as the PR number.
- Implementation options:
  - **actions/github-script**: One step that uses `github.rest.issues.createComment({ owner, repo, issue_number, body })`. No extra actions.
  - **peter-evans/create-or-update-comment** (or find-comment + update): If we want a single “plots” comment that is updated on every run instead of a new comment each time, we find a comment by a fixed identifier (e.g. body contains “<!-- plots -->”) and create or update it.

**Recommendation**: Use a single comment that is updated on each run (find by marker like `<!-- plots -->`, then create or update). That keeps the PR tidy. Use `peter-evans/create-or-update-comment` or equivalent (find-comment + create/update via API).

## Permissions

- For posting an issue/PR comment: `GITHUB_TOKEN` with default permissions is enough (pull-requests: write or contents: read + issues: write depending on repo settings; typically default is sufficient).
- If we use Gist for inline images: a PAT with `gist` scope in a repo secret.

## Failure handling

- If `make all-tasks` fails: the **plots** job fails; no comment is posted. Optionally add a step that posts a short “Plots could not be generated” comment; otherwise the PR author sees the failed job.
- If the two PNGs are missing after a successful `make all-tasks` (e.g. 2026 season skipped): only post a comment if both files exist; otherwise skip or mention that plots were not produced.

## File changes (implementation phase)

- **.github/workflows/validate.yml**  
  - Add a **plots** job that:
    - `if: github.event_name == 'pull_request'`
    - `needs: validate`
    - Same runner and R/setup steps as validate (or a reusable workflow).
    - Step: `make all-tasks` (with timeout if desired).
    - Step: upload `plots/2026/unrivaled_elo_rankings.png` and `plots/2026/unrivaled_rankings.png` as artifacts.
    - Step: build comment body (artifact link or image markdown with URLs).
    - Step: create or update PR comment (e.g. with `peter-evans/create-or-update-comment` or `actions/github-script`).

No other files in the repo need to change for this plan (only the workflow file and, if you choose inline images, one new repo secret).

## Summary

- Add a **plots** job that runs only on `pull_request`, after **validate**, runs `make all-tasks`, uploads the two 2026 PNGs as artifacts, and posts (or updates) a single PR comment.
- **Your choice needed**: artifact-only comment vs inline images; if inline, Gist (PAT with gist) vs another host (e.g. imgur + API key).
