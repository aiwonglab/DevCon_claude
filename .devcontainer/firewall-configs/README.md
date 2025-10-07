# Firewall Configuration

Modular firewall configuration system for controlling network access in the devcontainer.

## Quick Start

### Option 1: Use a Profile (Recommended)

Set `FIREWALL_PROFILE` in your `devcontainer.json`:

```json
{
  "containerEnv": {
    "FIREWALL_PROFILE": "ai-dev"
  }
}
```

### Option 2: Custom Categories

Set `FIREWALL_CATEGORIES` directly:

```json
{
  "containerEnv": {
    "FIREWALL_CATEGORIES": "core,ai-services,package-managers"
  }
}
```

## Available Profiles

| Profile | Categories | Use Case |
|---------|-----------|----------|
| **minimal** | core, package-managers, os-packages | Lightweight development without AI/cloud |
| **ai-dev** | core, ai-services, package-managers, os-packages | AI/ML development (OpenAI, Anthropic, HuggingFace, Ollama) |
| **cloud-dev** | core, cloud-providers, package-managers, os-packages | Cloud infrastructure development (GCP, AWS, Azure) |
| **full** | All categories | Maximum flexibility |

## Available Categories

Categories are defined in `firewall-domains/`:

- **core** - Essential services (Anthropic, Sentry, Statsig)
- **ai-services** - AI/ML providers (OpenAI, Ollama, HuggingFace, PyTorch)
- **package-managers** - Package registries (npm, PyPI, uv, pixi)
- **cloud-providers** - Cloud APIs (GCP, AWS, Azure)
- **os-packages** - OS package repos (Ubuntu, Debian)

## Adding New Domains

### To an Existing Category

Edit the appropriate file in `firewall-domains/`:

```bash
# Example: Add a new AI service
echo "replicate.com" >> firewall-domains/ai-services.txt
```

### Create a New Category

1. Create a new file in `firewall-domains/`:
   ```bash
   cat > firewall-domains/databases.txt <<EOF
   # Database services
   mongodb.com
   postgresql.org
   EOF
   ```

2. Add to a profile or use directly:
   ```bash
   FIREWALL_CATEGORIES="core,databases,package-managers"
   ```

### Create a Custom Profile

Create a new `.env` file in `firewall-configs/`:

```bash
cat > firewall-configs/my-profile.env <<EOF
# My custom profile
FIREWALL_CATEGORIES="core,ai-services,databases,package-managers"
EOF
```

Then use it:
```json
{
  "containerEnv": {
    "FIREWALL_PROFILE": "my-profile"
  }
}
```

## File Format

Domain files support:
- One domain per line
- Comments with `#`
- Empty lines (ignored)

Example:
```txt
# AI Services
api.openai.com
platform.openai.com

# Model hosting
huggingface.co
```

## Troubleshooting

### Domain not resolving
Check the init script output for DNS resolution failures. The script retries 3 times before skipping.

### Profile not found
Verify the profile name matches the filename (without `.env`):
```bash
ls .devcontainer/firewall-configs/
```

### Testing access
After container starts:
```bash
# Should succeed (if in your categories)
curl -I https://api.anthropic.com

# Should fail (not in any category)
curl -I https://example.com
```

## Architecture

```
.devcontainer/
├── firewall-configs/          # Profile definitions
│   ├── minimal.env
│   ├── ai-dev.env
│   ├── cloud-dev.env
│   └── full.env
├── firewall-domains/          # Category domain lists
│   ├── core.txt
│   ├── ai-services.txt
│   ├── package-managers.txt
│   ├── cloud-providers.txt
│   └── os-packages.txt
└── init-firewall.sh           # Firewall setup script
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FIREWALL_PROFILE` | Profile name to load | None (uses default categories) |
| `FIREWALL_CATEGORIES` | Comma-separated category list | All categories |

Profile loading takes precedence over direct category specification.
