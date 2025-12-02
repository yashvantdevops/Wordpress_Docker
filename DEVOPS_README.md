# WordPress Multi-Environment Docker Deployment Guide

**Industry-Standard DevOps Setup for Development, Staging, and Production**

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Naming Conventions](#naming-conventions)
3. [Environment Configurations](#environment-configurations)
4. [Quick Start](#quick-start)
5. [Detailed Setup & Deployment](#detailed-setup--deployment)
6. [Volume & Network Strategy](#volume--network-strategy)
7. [Monitoring & Debugging](#monitoring--debugging)
8. [Production Deployment Checklist](#production-deployment-checklist)
9. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

This setup follows a **three-tier deployment model**:

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Compose Layers                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  docker-compose.yaml (Base)                                 │
│  ├── MySQL 8.1 (db)                                         │
│  ├── Redis 7 (redis)                                        │
│  ├── WordPress App (wordpress)                              │
│  ├── phpMyAdmin (phpmyadmin) [dev profile]                  │
│  └── WP-CLI (wpcli) [dev profile]                           │
│                                                              │
│  +  docker-compose.dev.yaml (Development)                   │
│     ├── Networks: wordpress_dev_network                     │
│     ├── Volumes: wordpress_dev_* (html, uploads, cache)     │
│     ├── Containers: wordpress_dev_*                         │
│     ├── Ports: 8080 (WP), 8081 (phpMyAdmin)                 │
│     ├── Debug: ON, No resource limits                       │
│     └── Services: ALL (db, redis, wordpress, admin tools)   │
│                                                              │
│  +  docker-compose.staging.yaml (Staging)                   │
│     ├── Networks: wordpress_staging_network                 │
│     ├── Volumes: wordpress_staging_* (html, uploads, cache) │
│     ├── Containers: wordpress_staging_*                     │
│     ├── Ports: 9080 (WP), 9081 (phpMyAdmin)                 │
│     ├── Debug: OFF, Moderate resource limits                │
│     └── Services: Core only (no admin tools)                │
│                                                              │
│  +  docker-compose.prod.yaml (Production)                   │
│     ├── Networks: wordpress_prod_network                    │
│     ├── Volumes: wordpress_prod_* (uploads, cache)          │
│     ├── Containers: wordpress_prod_*                        │
│     ├── Ports: 80 (WP) via reverse proxy                    │
│     ├── Debug: OFF, Strict resource + security              │
│     └── Services: Core only (immutable, no admin expose)    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Naming Conventions

### Container Names
- **Development**: `wordpress_dev_*` (e.g., `wordpress_dev_app`, `wordpress_dev_db`, `wordpress_dev_redis`, `wordpress_dev_cli`)
- **Staging**: `wordpress_staging_*` (e.g., `wordpress_staging_app`, `wordpress_staging_db`)
- **Production**: `wordpress_prod_*` (e.g., `wordpress_prod_app`, `wordpress_prod_db`)

### Network Names
- **Development**: `wordpress_dev_network`
- **Staging**: `wordpress_staging_network`
- **Production**: `wordpress_prod_network`

### Volume Names
- **Development**:
  - `wordpress_dev_html` — WordPress source code
  - `wordpress_dev_uploads` — User-uploaded files
  - `wordpress_dev_cache` — Transient cache
  - `wp_db_data` — MySQL data (shared base name)
  - `wp_redis_data` — Redis data (shared base name)

- **Staging**:
  - `wordpress_staging_html` — WordPress source code
  - `wordpress_staging_uploads` — User-uploaded files
  - `wordpress_staging_cache` — Transient cache

- **Production**:
  - `wordpress_prod_uploads` — User-uploaded files (code is baked into image)
  - `wordpress_prod_cache` — Transient cache
  - *(DB and Redis volumes managed separately or externally)*

### Image Names
- `wp_wordpress:latest` — custom WordPress image with Redis PHP extension

---

## Environment Configurations

### Development (`.env.dev`)
- **Purpose**: Local development with debug output, hot-reload, and full toolset
- **Debug**: Enabled
- **Resource Limits**: None
- **Services**: WordPress + MySQL + Redis + phpMyAdmin + WP-CLI
- **Ports**: 8080 (WP), 8081 (phpMyAdmin)
- **Build**: development (includes Xdebug, Composer, Git)

### Staging (`.env.staging`)
- **Purpose**: Pre-production testing, performance validation
- **Debug**: Disabled
- **Resource Limits**: Moderate (1GB memory, 2 CPUs)
- **Services**: WordPress + MySQL + Redis (no admin tools exposed)
- **Ports**: 9080 (WP), 9081 (phpMyAdmin, internal only)
- **Build**: staging (includes Composer, excludes Xdebug)

### Production (`.env.prod`)
- **Purpose**: Live deployment, maximum security and performance
- **Debug**: Disabled
- **Resource Limits**: Strict (2GB memory limit, CPU affinity)
- **Services**: WordPress + MySQL + Redis (core only)
- **Ports**: 80 (via reverse proxy/load balancer)
- **Build**: production (minimal, no dev tools)
- **Security**: read-only root filesystem, capability dropping, no new privileges

---

## Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 1.29+
- PowerShell (Windows) or Bash (Linux/macOS)

### 1. Clone and Setup
```powershell
cd c:\Users\Yashv\Downloads\Projects\MultiTier\wordpress-mysql

# Copy the appropriate .env file for your environment
Copy-Item .env.dev -Destination .env -Force
```

### 2. Development (Default)
```powershell
# Build and start dev stack
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build

# Verify all services
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml ps

# View logs
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f wordpress
```

### 3. Access Services
- **WordPress**: http://localhost:8080
- **phpMyAdmin**: http://localhost:8081 (DB: db, User: wp_user_dev)
- **WP-CLI**: `docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli core version`

### 4. First-Run Setup
```powershell
# Run WordPress installation via web UI (admin setup), then run:
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin install redis-cache --activate

# Enable Redis object cache
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis enable
```

---

## Detailed Setup & Deployment

### Development Deployment

**Command**:
```powershell
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build
```

**What Happens**:
1. Builds WordPress image with development tools (Xdebug, Composer, Git)
2. Creates `wordpress_dev_network`
3. Mounts source code in `wordpress_dev_html` for live editing
4. Starts phpMyAdmin and WP-CLI for admin tasks
5. Enables debug output to stdout and `wp-content/debug.log`

**Typical Workflow**:
```powershell
# Start environment
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d

# Install WordPress via UI (http://localhost:8080)
# Install Redis plugin
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin install redis-cache --activate

# Run custom setup script
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress /bin/bash /scripts/init-wordpress.sh

# View debug logs
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f wordpress

# Stop environment
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down
```

---

### Staging Deployment

**Command**:
```powershell
# Update .env.staging with your credentials
notepad .env.staging

# Deploy
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging up -d --build
```

**Differences from Development**:
- Uses `staging` build environment (no Xdebug, includes Composer)
- No phpMyAdmin or WP-CLI exposed
- Resource limits enforced: 1GB memory
- Debug disabled, output to file only
- Production-like configuration

**Pre-Deployment Checklist**:
- [ ] Update DB credentials in `.env.staging`
- [ ] Set strong passwords (min. 20 chars)
- [ ] Review Redis policy (`allkeys-lfu`)
- [ ] Test backup/restore procedures
- [ ] Verify all plugins work under resource limits

---

### Production Deployment

**Prerequisites**:
- Change **all passwords** in `.env.prod` (use a password manager)
- Set up SSL/TLS reverse proxy (Nginx, Traefik, or AWS ALB)
- Configure external database (optional, for HA)
- Set up automated backups (see [Backups](#backups))
- Enable centralized logging (see [Monitoring & Debugging](#monitoring--debugging))

**Command**:
```powershell
# 1. Prepare production environment
notepad .env.prod
# ⚠️ Update ALL passwords, set MYSQL_ROOT_PASSWORD, MYSQL_PASSWORD, etc.

# 2. Build production image (optional: push to registry)
docker build --build-arg BUILD_ENV=production -t wp_wordpress:prod-v1.0 ./docker/wordpress
# docker push your-registry/wp_wordpress:prod-v1.0

# 3. Deploy
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod up -d --build

# 4. Verify health
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml ps
```

**Production-Specific Settings**:
- Code is **immutable** (baked into image, no host bind)
- Only `/wp-content/uploads` and `/wp-content/cache` are writable
- Resource limits: 2GB memory, 2 CPU cores
- Security: dropped capabilities, no new privileges, readonly root FS where possible
- No debug output in logs
- phpMyAdmin and WP-CLI not exposed (manage via CI/CD pipeline)

---

## Volume & Network Strategy

### Development Volumes
```yaml
wordpress_dev_html:       # WordPress source code (writable for theme/plugin dev)
  ├── /wp-admin
  ├── /wp-content
  │   ├── /uploads         ← wordpress_dev_uploads (persistent)
  │   └── /cache           ← wordpress_dev_cache (ephemeral)
  ├── /wp-includes
  └── wp-config.php

wp_db_data:               # MySQL data (persists across restarts)
wp_redis_data:            # Redis RDB/AOF (persists cache keys)
```

**Characteristics**:
- **Bind mount** or **named volume** for full file system access
- Changes to source code immediately reflected in running container
- Database and Redis data persist between `docker compose down`
- Ideal for local development and debugging

### Staging Volumes
```yaml
wordpress_staging_html:       # Read-mostly (theme/plugin code)
  ├── /wp-content/uploads     # User uploads (writable)
  └── /wp-content/cache       # Transient cache (writable)

wp_db_data:                   # MySQL data (HA-ready if external)
wp_redis_data:                # Redis data (distributed if cluster)
```

**Characteristics**:
- Separate volumes for code, uploads, and cache
- Production-like volume isolation
- Can test backup/restore workflows
- Database suitable for external (RDS, Azure Database)

### Production Volumes
```yaml
wordpress_prod_uploads:       # User uploads only (code in image)
wordpress_prod_cache:         # Cache (ephemeral-friendly)

# External storage (not Docker volumes):
- S3 / Cloud Storage for wp-content/uploads
- Managed database service (RDS, CloudSQL, etc.)
- Redis cluster or managed service
```

**Characteristics**:
- **Immutable application code** (part of Docker image)
- Only **persistent user data** in volumes (uploads, cache)
- Simplifies image promotion across environments
- Enables stateless container scaling

### Network Isolation

Each environment has its own **bridge network** to prevent cross-environment communication:

```
Development Network (wordpress_dev_network)
├── wordpress_dev_app → redis (internal:6379)
├── wordpress_dev_app → db (internal:3306)
├── wordpress_dev_phpmyadmin → db
└── wordpress_dev_cli → wordpress_dev_app

Staging Network (wordpress_staging_network)
├── wordpress_staging_app → redis (internal:6379)
├── wordpress_staging_app → db (internal:3306)
└── (no admin tools)

Production Network (wordpress_prod_network)
├── wordpress_prod_app → redis (internal:6379)
├── wordpress_prod_app → db (internal:3306)
└── (no direct database admin access)
```

---

## Monitoring & Debugging

### Logs

**View Logs**:
```powershell
# All services
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f

# Specific service
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f wordpress

# Last 100 lines, specific service
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f --tail=100 wordpress

# Save to file
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs > logs.txt
```

**WordPress Debug Log**:
```powershell
# Inside container
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress tail -f /var/www/html/wp-content/debug.log

# From host
cat \\.\pipe\wordpress_dev_app  # Windows
```

### Health Checks

Each service has health checks configured:

```powershell
# Check service health
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml ps

# Manually verify
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec db \
  mysqladmin ping -h localhost -u root -pROOT_PASSWORD

docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec redis \
  redis-cli ping
```

### Performance Monitoring

**CPU & Memory Usage**:
```powershell
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml stats

# Output example:
# CONTAINER ID    CPU %    MEM USAGE / LIMIT    MEM %
# abc123...       2.5%     256MiB / 2GiB        12.5%
```

**Database Query Slow Log**:
```powershell
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec db \
  tail -f /var/log/mysql/slow-query.log
```

### Network Diagnostics

```powershell
# Test connectivity between services
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress \
  ping redis

docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress \
  ping db

# Test Redis connection
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec redis \
  redis-cli -h redis ping
```

---

## Production Deployment Checklist

### Before Going Live

- [ ] **Database**
  - [ ] Change `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` to random 32-char strings
  - [ ] Enable binary logging for backups: `binlog_format=ROW`
  - [ ] Schedule automated backups (daily, 30-day retention)
  - [ ] Test restore procedure

- [ ] **Redis**
  - [ ] Set `maxmemory` policy (default: `volatile-lfu`)
  - [ ] Enable AOF (Append Only File) for durability
  - [ ] Monitor memory usage

- [ ] **WordPress**
  - [ ] Disable `WP_DEBUG` and `WP_DEBUG_DISPLAY`
  - [ ] Install Redis Object Cache plugin and verify enabled
  - [ ] Set `WP_MEMORY_LIMIT` to 256M (or 512M for large sites)
  - [ ] Install security plugins (Wordfence, Sucuri)
  - [ ] Enable two-factor authentication for admin accounts

- [ ] **Networking**
  - [ ] Set up SSL/TLS certificate (Let's Encrypt or AWS ACM)
  - [ ] Configure reverse proxy (Nginx, Traefik, ALB)
  - [ ] Enable HTTP/2 and gzip compression
  - [ ] Set up DDoS protection (CloudFlare, AWS Shield)

- [ ] **Security**
  - [ ] Scan for vulnerabilities: `docker scan wp_wordpress:prod-v1.0`
  - [ ] Enable AppArmor or SELinux
  - [ ] Configure firewall rules (whitelist IPs if needed)
  - [ ] Remove default WordPress user, rename `admin` account
  - [ ] Disable file editing: `define('DISALLOW_FILE_EDIT', true)`

- [ ] **Monitoring & Alerting**
  - [ ] Set up centralized logging (ELK, Datadog, CloudWatch)
  - [ ] Configure health checks and alerts
  - [ ] Monitor disk usage (80% threshold alert)
  - [ ] Monitor database replication lag (if applicable)

- [ ] **Backups & Recovery**
  - [ ] Test full restore from backup
  - [ ] Document RTO/RPO targets
  - [ ] Set up geo-redundant backup storage

### Deployment Commands

```powershell
# 1. Tag and push image to registry
docker build --build-arg BUILD_ENV=production -t my-registry/wp_wordpress:prod-v1.0.0 ./docker/wordpress
docker push my-registry/wp_wordpress:prod-v1.0.0

# 2. Update docker-compose.prod.yaml to use registry image (if using CI/CD)
# Change: image: wp_wordpress:latest → image: my-registry/wp_wordpress:prod-v1.0.0

# 3. Deploy on production server
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod up -d

# 4. Verify
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml ps
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml exec wordpress curl -I http://localhost/
```

---

## Troubleshooting

### "Connection refused: db:3306"

**Cause**: WordPress trying to connect before MySQL is healthy.

**Solution**:
```powershell
# Verify MySQL is running and healthy
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml ps
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs db

# Wait for health check to pass, then restart WordPress
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml restart wordpress
```

### "Redis connection error"

**Cause**: Redis container crashed or not responding.

**Solution**:
```powershell
# Check Redis logs
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs redis

# Verify Redis is listening
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec redis redis-cli ping

# Restart Redis
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml restart redis
```

### "WordPress blank page / 502 error"

**Cause**: PHP/WordPress crashed, memory limit exceeded, or misconfigured.

**Solution**:
```powershell
# Check WordPress logs
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs wordpress
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress tail -f /var/www/html/wp-content/debug.log

# Check memory usage
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml stats wordpress

# Increase PHP memory limit (edit docker-compose.yaml or .env)
# WORDPRESS_PHP_MEMORY_LIMIT=512M

# Restart WordPress
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml restart wordpress
```

### "Cannot write to wp-content/uploads"

**Cause**: Permission issue or volume not mounted correctly.

**Solution**:
```powershell
# Verify volume is mounted
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress mount | grep wp-content

# Fix permissions (inside container)
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress \
  chown -R www-data:www-data /var/www/html/wp-content

# Or from host (Windows):
icacls "D:\path\to\volumes\wordpress_dev_uploads" /grant "Everyone:(OI)(CI)(F)"
```

### "Port 8080 already in use"

**Cause**: Another service or environment using the same port.

**Solution**:
```powershell
# Find what's using port 8080
netstat -ano | findstr :8080

# Option 1: Stop other services
docker compose down

# Option 2: Change port in .env
notepad .env.dev
# Change WP_PORT=8080 → WP_PORT=8888

# Restart
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml up -d --build
```

---

## Common WP-CLI Commands

```powershell
# Create a compose alias for convenience
$alias = 'alias compose_dev="docker compose -f docker-compose.yaml -f docker-compose.dev.yaml"'

# WordPress info
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli core version
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli db tables

# Plugin management
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin list
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin install hello-dolly --activate

# Theme management
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli theme list
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli theme activate twentytwentythree

# User management
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli user list
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli user create admin admin@example.com --role=administrator

# Database export/import
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli db export - > backup.sql
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli db import backup.sql

# Redis commands
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis status
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis enable
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis info
```

---

## Additional Resources

- **Docker Compose**: https://docs.docker.com/compose/
- **WordPress Official Image**: https://hub.docker.com/_/wordpress
- **Redis Documentation**: https://redis.io/docs/
- **MySQL 8.1 Documentation**: https://dev.mysql.com/doc/
- **WordPress Security**: https://wordpress.org/support/article/hardening-wordpress/

---

## Support & Contributions

For issues, suggestions, or contributions:
1. Check existing logs and health checks
2. Review this guide's troubleshooting section
3. Consult Docker and WordPress documentation
4. Open an issue with environment details and error messages

---

**Last Updated**: December 2, 2025
**Version**: 1.0 (Production-Ready)
