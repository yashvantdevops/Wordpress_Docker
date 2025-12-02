# Project Structure & File Summary

## Complete Directory Layout

```
wordpress-mysql/
│
├── 📄 docker-compose.yaml              ← BASE COMPOSE (core services definition)
│   └── Defines: db, redis, wordpress, phpmyadmin, wpcli
│       Networks & Volumes: defined in overrides
│
├── 📄 docker-compose.dev.yaml          ← DEVELOPMENT OVERRIDE
│   └── Network: wordpress_dev_network
│       Volumes: wordpress_dev_html, wordpress_dev_uploads, wordpress_dev_cache
│       Containers: wordpress_dev_app, wordpress_dev_db, etc.
│       Services: ALL (includes phpmyadmin + wpcli)
│       Debug: ON | Ports: 8080 (WP), 8081 (phpMyAdmin)
│
├── 📄 docker-compose.staging.yaml      ← STAGING OVERRIDE
│   └── Network: wordpress_staging_network
│       Volumes: wordpress_staging_html, wordpress_staging_uploads, wordpress_staging_cache
│       Containers: wordpress_staging_app, wordpress_staging_db, etc.
│       Services: Core only (no admin tools)
│       Debug: OFF | Ports: 9080 (WP), 9081 (internal)
│       Resource Limits: 1GB memory, 1-2 CPUs
│
├── 📄 docker-compose.prod.yaml         ← PRODUCTION OVERRIDE
│   └── Network: wordpress_prod_network
│       Volumes: wordpress_prod_uploads, wordpress_prod_cache (code in image)
│       Containers: wordpress_prod_app, wordpress_prod_db, etc.
│       Services: Core only (no admin tools exposed)
│       Debug: OFF | Port: 80 (via reverse proxy)
│       Security: Strict (cap drop, no-new-privileges, readonly FS)
│       Resource Limits: 2GB memory, 2 CPUs + CPU affinity
│
├── 📝 .env                             ← CURRENT ENVIRONMENT (MANUAL: symlink or copy from .env.*)
├── 📝 .env.dev                         ← Development environment variables
│   └── BUILD_ENV=development, MYSQL_ROOT_PASSWORD, WP_PORT=8080, WP_DEBUG=true, etc.
│
├── 📝 .env.staging                     ← Staging environment variables
│   └── BUILD_ENV=staging, MEMORY_LIMIT=1024m, WP_PORT=9080, WP_DEBUG=false, etc.
│
├── 📝 .env.prod                        ← Production environment variables
│   └── BUILD_ENV=production, MEMORY_LIMIT=2048m, WP_PORT=80, WP_DEBUG=false, etc.
│   ⚠️  SECURITY: Change all passwords before deploying!
│
├── 🐳 docker/
│   └── wordpress/
│       ├── 📄 Dockerfile               ← Multi-environment WordPress image
│       │   └── ARG BUILD_ENV (development | staging | production)
│       │       Development: +xdebug, +composer, +git
│       │       Staging: +composer, +git
│       │       Production: -dev tools, optimized (minimal)
│       │       All: redis extension, php extensions, healthcheck
│       │
│       └── .htaccess.template          ← (Optional) Apache rewrite rules
│
├── 🔧 scripts/
│   └── 📄 init-wordpress.sh            ← First-run setup script
│       └── Installs Redis plugin, configures permalinks, sets timezone
│
├── 📖 README.md                        ← Original project README
├── 📖 DEVOPS_README.md                 ← COMPREHENSIVE DEVOPS GUIDE (THIS IS YOUR MAIN REFERENCE)
│   └── Architecture | Naming | Environment Configs | Setup | Volumes/Networks
│       Monitoring | Production Checklist | Troubleshooting | WP-CLI Commands
│
└── 📖 QUICKREF.md                      ← QUICK REFERENCE GUIDE
    └── File structure | Naming table | Quick commands | Aliases
        First-time setup | Key differences | Diagnostics
```

---

## File Descriptions

### `docker-compose.yaml` (Base)
**Purpose**: Defines all services (wordpress, db, redis, phpmyadmin, wpcli)

**Contains**:
- MySQL 8.1 service with health check
- Redis 7 service with persistence
- WordPress app build definition (no container_name, no networks defined here)
- phpMyAdmin service (dev profile)
- WP-CLI service (dev profile)

**Key**: Does NOT define networks/volumes directly (left to overrides)

---

### `docker-compose.dev.yaml` (Development Override)
**Purpose**: Add development-specific configuration, networks, and volumes

**Contains**:
- Container names: `wordpress_dev_*`
- Network: `wordpress_dev_network`
- Volumes: `wordpress_dev_html`, `wordpress_dev_uploads`, `wordpress_dev_cache`
- Ports: 8080 (WP), 8081 (phpMyAdmin)
- Debug env vars: `WP_DEBUG=true`
- All services exposed (admin tools included)

**Used by**: Local developers, debugging, testing

---

### `docker-compose.staging.yaml` (Staging Override)
**Purpose**: Add staging-specific configuration, networks, volumes, and resource limits

**Contains**:
- Container names: `wordpress_staging_*`
- Network: `wordpress_staging_network`
- Volumes: `wordpress_staging_html`, `wordpress_staging_uploads`, `wordpress_staging_cache`
- Ports: 9080 (WP), 9081 (internal)
- Debug env vars: `WP_DEBUG=false`
- Resource limits: 1GB memory, 1-2 CPUs
- No admin tools exposed (manage via CI/CD)

**Used by**: QA, pre-production testing, performance validation

---

### `docker-compose.prod.yaml` (Production Override)
**Purpose**: Add production-specific configuration, security hardening, strict resource limits

**Contains**:
- Container names: `wordpress_prod_*`
- Network: `wordpress_prod_network`
- Volumes: `wordpress_prod_uploads`, `wordpress_prod_cache` (code in image, not mounted)
- Port: 80 (behind reverse proxy)
- Debug env vars: `WP_DEBUG=false`
- Security: `cap_drop`, `cap_add`, `no-new-privileges`
- Strict resource limits: 2GB memory, 2 CPUs, CPU affinity
- No admin tools exposed

**Used by**: Live production deployment

---

### `.env.dev` / `.env.staging` / `.env.prod`
**Purpose**: Environment-specific configuration (passwords, ports, debug flags, resource limits)

**Example Contents**:
```env
BUILD_ENV=development          # Dockerfile build target
ENVIRONMENT=dev
MYSQL_ROOT_PASSWORD=...        # Database passwords (⚠️  change these!)
MYSQL_DATABASE=wordpress_dev
MYSQL_USER=wp_user_dev
MYSQL_PASSWORD=...
WP_TABLE_PREFIX=wp_dev_
WP_PORT=8080
PHPMYADMIN_PORT=8081
WP_DEBUG=true
WP_DEBUG_DISPLAY=true
WP_DEBUG_LOG=/var/www/html/wp-content/debug.log
REDIS_MAXMEMORY=128mb
REDIS_POLICY=allkeys-lru
COMPOSE_PROJECT_NAME=wordpress-dev
```

---

### `docker/wordpress/Dockerfile`
**Purpose**: Build WordPress image with multi-environment support

**Features**:
- `ARG BUILD_ENV=development` — Accepts build argument
- Installs PHP extensions: gd, intl, zip, opcache, redis
- Conditionally installs dev tools based on `BUILD_ENV`:
  - **development**: +xdebug, +composer, +git
  - **staging**: +composer, +git
  - **production**: Remove all build tools
- Optimizes opcache for production
- Sets proper file permissions
- Includes health check

**Build Commands**:
```bash
# Development
docker build --build-arg BUILD_ENV=development -t wp_wordpress:dev ./docker/wordpress

# Staging
docker build --build-arg BUILD_ENV=staging -t wp_wordpress:staging ./docker/wordpress

# Production
docker build --build-arg BUILD_ENV=production -t wp_wordpress:prod ./docker/wordpress
```

---

### `scripts/init-wordpress.sh`
**Purpose**: First-run setup script (optional, run manually after installation)

**Does**:
1. Verifies WordPress is installed
2. Sets correct permissions on wp-content
3. Installs & activates Redis Object Cache plugin
4. Enables Redis integration
5. Verifies Redis connectivity
6. Configures timezone and permalinks
7. Installs dev plugins (if in dev environment)

**Run**:
```bash
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress bash /scripts/init-wordpress.sh
```

---

### `DEVOPS_README.md`
**Purpose**: Comprehensive DevOps guide for this multi-environment setup

**Sections**:
1. Architecture Overview (ASCII diagrams)
2. Naming Conventions (containers, networks, volumes)
3. Environment Configurations (dev vs staging vs prod)
4. Quick Start (prerequisites, first run)
5. Detailed Setup & Deployment (per environment)
6. Volume & Network Strategy (data persistence, isolation)
7. Monitoring & Debugging (logs, health checks, performance)
8. Production Deployment Checklist (security, backups, monitoring)
9. Troubleshooting (common issues & solutions)
10. Common WP-CLI Commands (plugin, theme, user, database)

**When to Read**: Start here for comprehensive understanding!

---

### `QUICKREF.md`
**Purpose**: Quick reference for developers and operators

**Sections**:
1. File Structure (visual tree)
2. Naming Table (dev vs staging vs prod)
3. Quick Commands (start, logs, shell, stop per environment)
4. Shorthand Aliases (optional shell/PowerShell aliases)
5. First-Time Setup (5-step guide)
6. Key Differences (code, debug, limits, tools, security)
7. Useful Diagnostics (health checks, resource usage, connectivity)

**When to Use**: Quick lookup during daily work

---

## How to Use These Files

### First Time Setup
1. Read `QUICKREF.md` for overview
2. Read `DEVOPS_README.md` Architecture & Quick Start sections
3. Copy `.env.dev` → `.env` for development
4. Run: `docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env up -d --build`

### Daily Development
- Use commands from `QUICKREF.md`
- Check logs when issues arise
- Refer to Troubleshooting section if stuck

### Staging Deployment
- Copy `.env.staging` → `.env` (or reference it directly)
- Review DEVOPS_README.md Staging section
- Run: `docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging up -d --build`

### Production Deployment
- **CRITICAL**: Read DEVOPS_README.md Production Deployment Checklist
- Update `.env.prod` with secure passwords (32-char random)
- Review Production Deployment Commands in DEVOPS_README.md
- Run deployment command
- Verify health checks and monitoring

---

## Environment-at-a-Glance

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **Compose Command** | `-f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev` | `-f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging` | `-f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod` |
| **Container Prefix** | `wordpress_dev_*` | `wordpress_staging_*` | `wordpress_prod_*` |
| **Network** | wordpress_dev_network | wordpress_staging_network | wordpress_prod_network |
| **WordPress Port** | 8080 | 9080 | 80 |
| **Build Env** | development | staging | production |
| **Debug** | ON | OFF | OFF |
| **Admin Tools** | ✓ phpMyAdmin, WP-CLI | ✗ | ✗ |
| **Code Mounted** | ✓ (bind mount) | ✓ (volume) | ✗ (immutable image) |
| **Memory Limit** | None | 1GB | 2GB |
| **CPU Limit** | None | 1-2 cores | 2 cores |
| **Security** | Minimal | Moderate | Strict |
| **Use Case** | Local dev | QA/testing | Live production |

---

## Next Steps

1. **Start Development**: `docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build`
2. **Access WordPress**: http://localhost:8080
3. **Complete Setup**: Follow DEVOPS_README.md "First-Run Setup"
4. **Before Production**: Read and complete DEVOPS_README.md "Production Deployment Checklist"

---

**Version**: 1.0 (Production-Ready)  
**Last Updated**: December 2, 2025
