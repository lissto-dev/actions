# Lissto GitHub Actions

Create and manage [Lissto](https://lissto.dev) blueprints from GitHub Actions.

## Quick Start

```yaml
name: Create Blueprint
on:
  push:
    branches: [main]

jobs:
  blueprint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lissto-dev/actions/blueprint-create@v1
        with:
          api-key: ${{ secrets.LISSTO_API_KEY }}
          api-url: ${{ secrets.LISSTO_API_URL }}
```

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `api-key` | ✅ | Lissto API key |
| `api-url` | ✅ | Lissto API URL |
| `compose-file` | | Path to compose file (auto-detected if not set) |
| `branch` | | Git branch (auto-detected from `GITHUB_REF_NAME`) |
| `cli-version` | | Override CLI version (e.g., `v0.5.0`) |

## Outputs

| Output | Description |
|--------|-------------|
| `blueprint-id` | Created blueprint ID |

## Example with Outputs

```yaml
- uses: lissto-dev/actions/blueprint-create@v1
  id: blueprint
  with:
    api-key: ${{ secrets.LISSTO_API_KEY }}
    api-url: ${{ secrets.LISSTO_API_URL }}

- run: echo "Created blueprint ${{ steps.blueprint.outputs.blueprint-id }}"
```

## License

[Sustainable Use License](LICENSE)
