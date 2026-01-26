# Weekly Status Report Generator

Automated weekly status reports for the Bluefin project, posted to GitHub Discussions.

## Overview

This script generates weekly status reports by querying the [projectbluefin project board](https://github.com/orgs/projectbluefin/projects/2) for completed items and posting them to the Announcements section of GitHub Discussions.

## Features

- Queries organization project board for items marked "Done" in the past 7 days
- Categorizes items by area labels (gnome, dx, brew, services, infrastructure)
- Preserves label badges for each section
- Lists all contributors
- Automatically posts to GitHub Discussions

## Report Structure

Reports include:
- 📊 Summary (completed items, contributor count)
- 🖥️ Desktop (area/gnome, area/aurora, area/bling)
- 🛠️ Development (area/dx, area/buildstream, area/finpilot)
- 📦 Ecosystem (area/brew, area/just, area/bluespeed)
- ⚙️ System Services & Policies (area/services, area/policy)
- 🏗️ Infrastructure (area/iso, area/upstream)
- 👏 Contributors

## Usage

### Automated (GitHub Actions)
Reports run automatically every Saturday at 23:00 UTC via `.github/workflows/weekly-report.yml`.

**Important**: The workflow requires organization project read access. To enable this:

1. **Create a Personal Access Token (Classic)** or **GitHub App**:
   - For PAT (Classic): Go to GitHub Settings → Developer Settings → Personal Access Tokens → Tokens (classic)
   - Required scopes: `read:org`, `read:project`, `write:discussion`, `repo`

2. **Add as Repository Secret**:
   - Go to repository Settings → Secrets and variables → Actions
   - Create a new secret named `ORG_PROJECT_TOKEN`
   - Paste the token

3. The workflow will automatically use `ORG_PROJECT_TOKEN` if available, otherwise falls back to `GITHUB_TOKEN` (which will fail for org projects).

### Manual Trigger
1. Go to [Actions](../../actions/workflows/weekly-report.yml)
2. Click "Run workflow"
3. Select branch and click "Run workflow"

### Local Testing
```bash
cd scripts/weekly-report
npm install
export GITHUB_TOKEN="your_personal_access_token"
node generate-report.js
```

**Note**: Local testing requires a GitHub personal access token with:
- `repo` scope (read project data)
- `write:discussion` scope (post to discussions)

## Configuration

Key constants in `generate-report.js`:
- `PROJECT_ID`: Organization project board ID
- `ANNOUNCEMENTS_CATEGORY_ID`: Discussion category ID
- `AREA_SECTIONS`: Label mappings and colors for each section

## Label Preservation

Each section preserves its area labels with badges:
- Desktop: `#f5c2e7` (pink)
- Development: `#89dceb` (sky blue)
- Ecosystem: `#eba0ac` (peach)
- Services: `#b4befe` (lavender)
- Infrastructure: `#94e2d5` (teal)

Labels in each section are displayed as clickable badges that link to the label page.

## Dependencies

- `@octokit/graphql`: GitHub GraphQL API client
- Node.js 20+

## Related

- Issue: [#166](../../issues/166)
- Project Board: https://github.com/orgs/projectbluefin/projects/2
- Discussions: https://github.com/projectbluefin/common/discussions
