# WordPress Multi-Environment Docker - Quick Reference

## File Structure

```
wordpress-mysql/
├── docker-compose.yaml              # Base compose (core services)
├── docker-compose.dev.yaml          # Dev overrides (debug, admin tools)
├── docker-compose.staging.yaml      # Staging overrides (moderate limits)
├── docker-compose.prod.yaml         # Production overrides (strict security)
│
├── .env                             # Active environment config (symlink or copy)
├── .env.dev                         # Development settings
├── .env.staging                     # Staging settings
├── .env.prod                        # Production settings
│
├── docker/
│   └── wordpress/
│       └── Dockerfile              # Multi-stage: dev/staging/prod build
│
├── scripts/
│   └── init-wordpress.sh            # First-run setup script
│
├── README.md                        # Original README
└── DEVOPS_README.md                 # This comprehensive guide
```

## Environment-Specific Naming

| Component | Development | Staging | Production |
|-----------|-------------|---------|------------|
| **Network** | wordpress_dev_network | wordpress_staging_network | wordpress_prod_network |
| **App Container** | wordpress_dev_app | wordpress_staging_app | wordpress_prod_app |
| **DB Container** | wordpress_dev_db | wordpress_staging_db | wordpress_prod_db |
| **Redis Container** | wordpress_dev_redis | wordpress_staging_redis | wordpress_prod_redis |
| **HTML Volume** | wordpress_dev_html | wordpress_staging_html | (in image) |
| **Uploads Volume** | wordpress_dev_uploads | wordpress_staging_uploads | wordpress_prod_uploads |
| **Cache Volume** | wordpress_dev_cache | wordpress_staging_cache | wordpress_prod_cache |
| **WordPress Port** | 8080 | 9080 | 80 |
| **phpMyAdmin Port** | 8081 | 9081 | N/A (not exposed) |

## Quick Commands by Environment

### **Development**

```bash
# Start
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build

# Logs
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f

# Shell access
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress bash

# WP-CLI
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin list

# Stop
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down

# Clean (remove volumes & data)
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down -v
```

### **Staging**

```bash
# Start
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging up -d --build

# Logs
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml logs -f wordpress

# Monitor resources
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml stats

# Stop
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml down
```

### **Production**

```bash
# Start
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod up -d --build

# Health check
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml ps

# View logs
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml logs -f wordpress

# Stop (careful!)
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml down
```

## Shorthand Aliases (Optional)

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or PowerShell `$profile`):

```bash
# Bash / Zsh
alias wp-dev='docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev'
alias wp-stage='docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging'
alias wp-prod='docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod'

# Usage: wp-dev up -d   OR   wp-dev logs -f
```

```powershell
# PowerShell
function wp-dev { docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev @args }
function wp-stage { docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging @args }
function wp-prod { docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod @args }

# Usage: wp-dev up -d   OR   wp-dev logs -f
```

## First-Time Setup (Development)

```bash
# 1. Copy dev environment
cp .env.dev .env

# 2. Start services
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build

# 3. Wait for DB to be healthy (30-40 seconds)
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml ps
# STATUS should be: "healthy" for db and redis

# 4. Install WordPress via http://localhost:8080

# 5. Install and enable Redis plugin
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin install redis-cache --activate
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis enable

# 6. Done! Start developing
```

## Key Differences at a Glance

### Code & Volumes
- **Dev**: Source code on host, hot-reload enabled (bind mounts)
- **Staging**: Code in volume, production-like (read-mostly)
- **Prod**: Code in image, immutable (no mounts)

### Debug Output
- **Dev**: `WP_DEBUG=true`, output to screen & file
- **Staging**: `WP_DEBUG=false`, file only
- **Prod**: `WP_DEBUG=false`, minimal logging

### Resource Limits
- **Dev**: None (uses available system resources)
- **Staging**: 1GB memory, 1-2 CPUs
- **Prod**: 2GB memory, 2 CPUs + strict CPU affinity

### Admin Tools
- **Dev**: phpMyAdmin (8081), WP-CLI (included)
- **Staging**: None exposed (internal access via CI/CD)
- **Prod**: None exposed (manage externally)

### Security
- **Dev**: Debug on, no restrictions
- **Staging**: Debug off, basic limits
- **Prod**: Debug off, dropped capabilities, no-new-privileges, restricted FS

## Useful Diagnostics

```bash
# Check service health
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml ps

# View resource usage
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml stats

# Test connectivity
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress ping redis
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress ping db

# Check Redis
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec redis redis-cli ping
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec redis redis-cli INFO

# Check MySQL
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec db mysqladmin ping

# View environment variables
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress env | grep WORDPRESS
```

## Next Steps

1. **Read** `DEVOPS_README.md` for comprehensive documentation
2. **Start** with Development environment to test the setup
3. **Test** Staging before production deployment
4. **Follow** production checklist in DEVOPS_README.md before going live

---

For detailed setup, troubleshooting, and deployment guides, see **DEVOPS_README.md**.
