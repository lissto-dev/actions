# Lissto GitHub Actions

Deploy and manage [Lissto](https://lissto.dev) stacks from GitHub Actions.

## Actions

| Action | Description |
|--------|-------------|
| `lissto-dev/actions/deploy` | Deploy stack (creates blueprint + stack) |
| `lissto-dev/actions/update` | Update existing stack |
| `lissto-dev/actions/blueprint-create` | Create blueprint only |

## Quick Start

```yaml
- uses: lissto-dev/actions/deploy@v1
  with:
    api-key: ${{ secrets.LISSTO_API_KEY }}
    api-url: ${{ secrets.LISSTO_API_URL }}
    environment: production
```

## Examples

<details>
<summary><strong>Deploy on push to main</strong></summary>

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lissto-dev/actions/deploy@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: production
```
</details>

<details>
<summary><strong>Preview environments for PRs</strong></summary>

```yaml
name: Preview
on:
  pull_request:

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lissto-dev/actions/deploy@v1
        id: deploy
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: pr-${{ github.event.number }}
```
</details>

<details>
<summary><strong>Update on release</strong></summary>

```yaml
name: Update
on:
  release:
    types: [published]

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: lissto-dev/actions/update@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
          environment: production
          tag: ${{ github.event.release.tag_name }}
```
</details>

## Inputs

### Common

| Input | Required | Description |
|-------|----------|-------------|
| `api-key` | ✅ | Lissto API key |
| `api-url` | ✅ | Lissto API URL |
| `cli-version` | | Override CLI version (e.g., `v0.5.0`) |

### deploy

| Input | Required | Default |
|-------|----------|---------|
| `environment` | ✅ | |
| `compose-file` | | `docker-compose.yml` |
| `blueprint-id` | | (creates new) |
| `branch` / `tag` / `commit` | | (auto) |

### update

| Input | Required | Default |
|-------|----------|---------|
| `environment` | ✅ | |
| `stack` | | (all) |
| `branch` / `tag` / `commit` | | |

## Outputs

| Action | Outputs |
|--------|---------|
| **deploy** | `blueprint-id`, `stack-id`, `stack-url` |
| **update** | `stack-id`, `status`, `updated-services` |
| **blueprint-create** | `blueprint-id` |

## License

MIT
