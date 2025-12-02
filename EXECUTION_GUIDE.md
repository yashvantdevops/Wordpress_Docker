# 🚀 EXECUTION GUIDE: Start Your WordPress Environment

This guide walks you through starting each environment step-by-step.

---

## 📋 Prerequisites

- Docker Desktop installed (with Compose plugin)
- PowerShell or Bash terminal
- 4GB RAM minimum (8GB+ recommended for all environments)
- Ports available: 8080, 8081 (dev), 9080, 9081 (staging), 80 (prod)

**Check Docker Installation**:
```powershell
docker --version
docker compose version
```

---

## 🔧 DEVELOPMENT ENVIRONMENT

### Step 1: Navigate to Project
```powershell
cd c:\Users\Yashv\Downloads\Projects\MultiTier\wordpress-mysql
```

### Step 2: Select Development Environment
```powershell
# Use development .env
Copy-Item .env.dev -Destination .env -Force
```

### Step 3: Start Services
```powershell
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env.dev up -d --build
```

**What Happens**:
- Builds WordPress image with development tools (xdebug, composer, git)
- Creates `wordpress_dev_network`
- Creates volumes: `wordpress_dev_html`, `wordpress_dev_uploads`, `wordpress_dev_cache`
- Starts 5 containers: db, redis, wordpress, phpmyadmin, wpcli
- Takes ~60-90 seconds on first run (image build)

### Step 4: Wait for Services to be Healthy
```powershell
# Check status (repeat until all are "Up" and db/redis show "healthy")
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml ps

# Expected output:
# CONTAINER ID  IMAGE          COMMAND             CREATED       STATUS (2 seconds)        PORTS
# abc123...     mysql:8.1      "docker-entrypoint" 2 seconds ago  Up 2 seconds (healthy)    3306/tcp
# def456...     redis:7-a...   "redis-server ..."  2 seconds ago  Up 2 seconds (healthy)    6379/tcp
# ghi789...     wp_wordpre...  "docker-entrypoint" 2 seconds ago  Up 2 seconds (healthy)    0.0.0.0:8080->80/tcp
```

### Step 5: Install WordPress
**Open browser**: http://localhost:8080

1. Select Language (English)
2. Click "Continue"
3. Fill in database info:
   - Database Name: `wordpress_dev`
   - Username: `wp_user_dev`
   - Password: `wp_pass_dev123` (from `.env.dev`)
   - Database Host: `db`
   - Table Prefix: `wp_dev_`
4. Click "Submit"
5. Run Installation
6. Fill in site info:
   - Site Title: `WordPress Dev`
   - Username: `admin` (or custom)
   - Password: Use something strong
   - Email: `admin@localhost`
7. Click "Install WordPress"
8. Log in with credentials

### Step 6: Install & Enable Redis Plugin
```powershell
# Install Redis Object Cache plugin
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin install redis-cache --activate

# Enable Redis integration
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis enable

# Verify Redis is working
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli redis status
```

### Step 7: Access Admin Tools
- **WordPress Admin**: http://localhost:8080/wp-admin
- **phpMyAdmin**: http://localhost:8081 (User: `wp_user_dev`, Pass: `wp_pass_dev123`)
- **WP-CLI**: `docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli ...`

### Step 8: Start Developing!
Edit theme/plugin files in `docker/wordpress/` or directly in the container. Changes are live!

---

## 🧪 STAGING ENVIRONMENT

### Step 1: Navigate to Project
```powershell
cd c:\Users\Yashv\Downloads\Projects\MultiTier\wordpress-mysql
```

### Step 2: SECURITY WARNING: Update Passwords
```powershell
# Edit .env.staging with STRONG passwords
notepad .env.staging

# Change these lines:
# MYSQL_ROOT_PASSWORD=staging_root_secure_pwd_change_me          → Generate 32-char random pwd
# MYSQL_PASSWORD=wp_pass_staging_secure_change_me                → Generate 32-char random pwd
```

### Step 3: Start Staging Services
```powershell
# Stop any running dev environment first
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down

# Start staging
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env.staging up -d --build
```

### Step 4: Wait for Healthy Status
```powershell
# Repeat until all services show "Up" and "healthy"
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml ps
```

### Step 5: Install WordPress
- Open: http://localhost:9080
- Follow same steps as Development (Step 5)

### Step 6: Enable Redis
```powershell
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml run --rm wpcli plugin install redis-cache --activate
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml run --rm wpcli redis enable
```

### Step 7: Monitor Resource Usage
```powershell
# Watch CPU/memory (staging has limits: 1GB memory, 1-2 CPUs)
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml stats

# Test under load to see if limits are adequate
```

### Step 8: Verify No Debug Output
```powershell
# Check logs (should be clean, no WP_DEBUG output)
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml logs wordpress
```

---

## 🚀 PRODUCTION ENVIRONMENT

### ⚠️ CRITICAL: Pre-Deployment Checklist

- [ ] **Passwords**: Generate new random 32-char passwords
- [ ] **SSL/TLS**: Set up certificate (Let's Encrypt or AWS ACM)
- [ ] **Reverse Proxy**: Configure Nginx/Traefik/ALB to forward to port 80
- [ ] **Backups**: Automate daily backups with 30-day retention
- [ ] **Monitoring**: Set up logging (ELK, Datadog, CloudWatch)
- [ ] **Security Scan**: `docker scan wp_wordpress:prod-v1.0`
- [ ] **Read** DEVOPS_README.md section: "Production Deployment Checklist"

### Step 1: Stop All Other Environments
```powershell
# Clean up dev/staging
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml down
```

### Step 2: Update Production Secrets
```powershell
# ⚠️ DO NOT USE DEFAULT PASSWORDS
notepad .env.prod

# Generate strong passwords (use a password manager or:)
# powershell -Command "[System.Convert]::ToBase64String((1..32 | ForEach-Object { [byte](Get-Random -Min 32 -Max 127) })) -replace '=', ''"

# Update these:
MYSQL_ROOT_PASSWORD=<generate-strong-pwd>
MYSQL_PASSWORD=<generate-strong-pwd>
```

### Step 3: Build Production Image (Optional)
```powershell
# If deploying to a registry (e.g., Docker Hub, AWS ECR, Azure ACR)
docker build --build-arg BUILD_ENV=production -t my-registry/wp_wordpress:prod-v1.0 ./docker/wordpress

# Scan for vulnerabilities
docker scan my-registry/wp_wordpress:prod-v1.0

# Push to registry
docker push my-registry/wp_wordpress:prod-v1.0
```

### Step 4: Deploy Production Stack
```powershell
# Start production services
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env.prod up -d --build

# Verify all services are running and healthy
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml ps
```

### Step 5: Initialize WordPress
```powershell
# If this is a fresh installation, run WordPress setup via web UI or:
# (Skip if migrating existing database)

# Install plugins
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml run --rm wpcli plugin install redis-cache --activate

# Enable Redis
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml run --rm wpcli redis enable

# Verify
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml run --rm wpcli core version
```

### Step 6: Set Up Reverse Proxy (Nginx Example)
```nginx
# /etc/nginx/conf.d/wordpress.conf
upstream wordpress {
    server localhost:80;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    client_max_body_size 100M;

    gzip on;
    gzip_types text/plain text/css text/xml text/javascript application/json;

    location / {
        proxy_pass http://wordpress;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}
```

### Step 7: Set Up Automated Backups
```powershell
# Example: Daily database backup
# Create a scheduled task or cron job:

# Backup database
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml run --rm wpcli db export /backup/db_backup_$(Get-Date -Format "yyyyMMdd_HHmmss").sql

# Backup uploads
Compress-Archive -Path /path/to/uploads -DestinationPath "/backup/uploads_$(Get-Date -Format "yyyyMMdd").zip"

# Upload to S3/Azure/GCS
# aws s3 cp /backup/db_backup_*.sql s3://my-backup-bucket/wordpress/
```

### Step 8: Enable Monitoring & Alerting
```powershell
# Example: Send logs to CloudWatch, Datadog, or ELK

# Test that logs are being collected:
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml logs -f

# Configure log drivers in docker-compose.prod.yaml (optional):
# logging:
#   driver: awslogs
#   options:
#     awslogs-group: /ecs/wordpress-prod
#     awslogs-region: us-east-1
```

### Step 9: Monitor Production Health
```powershell
# Watch resources and container status
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml stats

# Check logs for errors
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml logs -f --tail=50

# Verify WordPress is responding
Invoke-WebRequest -Uri https://example.com

# Check database connectivity
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml exec db mysqladmin ping
```

---

## 🛑 Stopping Environments

### Development
```powershell
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down
# Keeps volumes (data persists)

docker compose -f docker-compose.yaml -f docker-compose.dev.yaml down -v
# Removes volumes (⚠️ data deleted!)
```

### Staging
```powershell
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml down
# Same as dev
```

### Production
```powershell
# ⚠️ Careful! This stops the live site
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml down

# Backups should be automated, but verify first:
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml run --rm wpcli db export
```

---

## 📊 Common Operations

### View Logs
```powershell
# Dev
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml logs -f wordpress

# Staging
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml logs -f wordpress

# Production
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml logs -f wordpress
```

### Access Shell
```powershell
# Dev
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml exec wordpress bash

# Staging
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml exec wordpress bash

# Production
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml exec wordpress bash
```

### Database Backup/Restore
```powershell
# Backup (all environments)
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli db export > backup.sql

# Restore
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli db import backup.sql
```

### Install Plugins
```powershell
# Dev
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml run --rm wpcli plugin install akismet --activate

# Staging
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml run --rm wpcli plugin install akismet --activate

# Production (via CI/CD, not manually recommended)
```

---

## 🆘 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| "Port 8080 already in use" | Change `WP_PORT` in `.env.dev` or stop other services |
| "Connection refused: db:3306" | Wait for MySQL health check to pass (`docker compose ps`) |
| "Redis connection failed" | Verify Redis container: `docker compose exec redis redis-cli ping` |
| "WordPress blank page" | Check logs: `docker compose logs wordpress` \| grep ERROR |
| "Can't write to uploads" | Fix permissions: `docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content` |
| "Forgot admin password" | `docker compose run --rm wpcli user list` then reset: `docker compose run --rm wpcli user update <id> --prompt=user_pass` |

For more: see **DEVOPS_README.md** Troubleshooting section

---

## 📚 Documentation Files

- **QUICKREF.md** — Quick commands & shortcuts
- **PROJECT_STRUCTURE.md** — File descriptions & architecture
- **DEVOPS_README.md** — Comprehensive guide (network, volumes, monitoring, production checklist)
- **This file** — Execution walkthrough

---

## 🎯 Next Steps After Deployment

1. **Verify**: Test site functionality, verify Redis is caching
2. **Secure**: Install security plugins, enable SSL, set up backups
3. **Monitor**: Set up logging, alerts, automated backups
4. **Scale**: If needed, consider container orchestration (Kubernetes, Docker Swarm)
5. **Maintain**: Regular updates, security patches, performance optimization

---

**Happy Deploying! 🚀**

For detailed reference, see **DEVOPS_README.md**
