# Lissto GitHub Actions

Deploy and manage your Lissto stacks directly from GitHub Actions.

## Available Actions

| Action | Description |
|--------|-------------|
| [`lissto-dev/actions/blueprint-create`](#blueprint-create) | Create a blueprint from docker-compose |
| [`lissto-dev/actions/deploy`](#deploy) | Full deployment (blueprint + stack) |
| [`lissto-dev/actions/update`](#update) | Update existing stack with new images |

## Quick Start

### 1. Set up secrets

Add these secrets to your repository:
- `LISSTO_API_KEY` - Your Lissto API key
- `LISSTO_API_URL` - Your Lissto API endpoint

### 2. Create workflow

```yaml
name: Deploy to Lissto

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to Lissto
        uses: lissto-dev/actions/deploy@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: production
          compose-file: docker-compose.yml
```

---

## Actions

### Blueprint Create

Create a Lissto blueprint from a docker-compose file.

```yaml
- name: Create Blueprint
  id: blueprint
  uses: lissto-dev/actions/blueprint-create@v1
  with:
    api-key: ${{ secrets.LISSTO_API_KEY }}
    api-url: ${{ secrets.LISSTO_API_URL }}
    compose-file: docker-compose.yml

- name: Use Blueprint ID
  run: echo "Blueprint ID: ${{ steps.blueprint.outputs.blueprint-id }}"
```

#### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api-key` | ✅ | - | Lissto API key |
| `api-url` | ✅ | - | Lissto API URL |
| `compose-file` | ❌ | `docker-compose.yml` | Path to docker-compose file |
| `repository` | ❌ | Auto-detected | Repository URL |
| `branch` | ❌ | Auto-detected | Git branch name |
| `author` | ❌ | Auto-detected | Author name |
| `cli-version` | ❌ | `latest` | Lissto CLI version |

#### Outputs

| Output | Description |
|--------|-------------|
| `blueprint-id` | The created blueprint ID |

---

### Deploy

Full deployment workflow that creates a blueprint (if needed) and deploys a stack.

```yaml
- name: Deploy to Lissto
  id: deploy
  uses: lissto-dev/actions/deploy@v1
  with:
    api-key: ${{ secrets.LISSTO_API_KEY }}
    api-url: ${{ secrets.LISSTO_API_URL }}
    environment: production
    compose-file: docker-compose.yml

- name: Show Deployment Info
  run: |
    echo "Stack ID: ${{ steps.deploy.outputs.stack-id }}"
    echo "URL: ${{ steps.deploy.outputs.stack-url }}"
```

#### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api-key` | ✅ | - | Lissto API key |
| `api-url` | ✅ | - | Lissto API URL |
| `environment` | ✅ | - | Target environment name |
| `compose-file` | ❌ | `docker-compose.yml` | Path to docker-compose file |
| `blueprint-id` | ❌ | - | Existing blueprint ID (skips creation) |
| `repository` | ❌ | Auto-detected | Repository URL |
| `branch` | ❌ | Auto-detected | Git branch for image resolution |
| `tag` | ❌ | - | Git tag for image resolution |
| `commit` | ❌ | - | Git commit SHA for image resolution |
| `cli-version` | ❌ | `latest` | Lissto CLI version |

#### Outputs

| Output | Description |
|--------|-------------|
| `blueprint-id` | The blueprint ID (created or provided) |
| `stack-id` | The created stack ID |
| `stack-url` | Primary URL of the deployed stack |

---

### Update

Update an existing stack with new container images.

```yaml
- name: Update Stack
  id: update
  uses: lissto-dev/actions/update@v1
  with:
    api-key: ${{ secrets.LISSTO_API_KEY }}
    api-url: ${{ secrets.LISSTO_API_URL }}
    environment: production
    branch: main

- name: Show Update Status
  run: |
    echo "Status: ${{ steps.update.outputs.status }}"
    echo "Updated: ${{ steps.update.outputs.updated-services }}"
```

#### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api-key` | ✅ | - | Lissto API key |
| `api-url` | ✅ | - | Lissto API URL |
| `environment` | ✅ | - | Environment where the stack is deployed |
| `stack` | ❌ | - | Stack name (optional if only one stack exists) |
| `branch` | ❌ | - | Git branch for image resolution |
| `tag` | ❌ | - | Git tag for image resolution |
| `commit` | ❌ | - | Git commit SHA for image resolution |
| `cli-version` | ❌ | `latest` | Lissto CLI version |

#### Outputs

| Output | Description |
|--------|-------------|
| `stack-id` | The updated stack ID |
| `updated-services` | Comma-separated list of updated services |
| `status` | Update status (`success` or `no-changes`) |

---

## Example Workflows

### Deploy on Push to Main

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to Lissto
        uses: lissto-dev/actions/deploy@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: production
```

### Preview Environments for Pull Requests

```yaml
name: Deploy Preview

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy Preview
        id: deploy
        uses: lissto-dev/actions/deploy@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: pr-${{ github.event.number }}
          branch: ${{ github.head_ref }}
      
      - name: Comment on PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `🚀 Preview deployed!\n\n**Stack ID:** \`${{ steps.deploy.outputs.stack-id }}\`\n**URL:** ${{ steps.deploy.outputs.stack-url || 'N/A' }}`
            })
```

### Update on Push (CI/CD Pipeline)

```yaml
name: Update Stack

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - name: Update Production Stack
        id: update
        uses: lissto-dev/actions/update@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: production
          branch: main
      
      - name: Check for Changes
        if: steps.update.outputs.status == 'no-changes'
        run: echo "No new images to deploy"
      
      - name: Report Update
        if: steps.update.outputs.status == 'success'
        run: |
          echo "Updated services: ${{ steps.update.outputs.updated-services }}"
```

### Multi-Environment Deployment

```yaml
name: Deploy

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Determine Environment
        id: env
        run: |
          if [ "${{ github.ref_name }}" = "main" ]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          else
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi
      
      - name: Deploy
        uses: lissto-dev/actions/deploy@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: ${{ steps.env.outputs.environment }}
          branch: ${{ github.ref_name }}
```

---

## CLI Version

By default, actions use the latest version of the Lissto CLI. To pin to a specific version:

```yaml
- uses: lissto-dev/actions/deploy@v1
  with:
    api-key: ${{ secrets.LISSTO_API_KEY }}
    api-url: ${{ secrets.LISSTO_API_URL }}
    environment: production
    cli-version: v0.5.0  # Pin to specific version
```

---

## Support

- **CLI Documentation:** [github.com/lissto-dev/cli](https://github.com/lissto-dev/cli)
- **Issues:** [GitHub Issues](https://github.com/lissto-dev/actions/issues)
- **Lissto Documentation:** [docs.lissto.dev](https://docs.lissto.dev)

## License

MIT License - see [LICENSE](LICENSE) for details.
