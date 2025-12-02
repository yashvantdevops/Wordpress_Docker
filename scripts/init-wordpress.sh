#!/bin/bash
# init-wordpress.sh
# First-run setup script: installs core plugins, sets up Redis, and configures WordPress.
# Run this inside the wordpress container after initial setup.

set -e

WP_CLI=/usr/local/bin/wp

echo "=== WordPress First-Run Setup ==="
echo "Environment: ${ENVIRONMENT:-development}"

# Verify WordPress installation
echo "[*] Checking WordPress installation..."
${WP_CLI} core is-installed 2>/dev/null || {
    echo "[!] WordPress not installed. Run installation first via web UI or wp-cli."
    exit 1
}

# Ensure wp-cli can write to wp-content
echo "[*] Setting permissions for wp-content..."
chmod -R 755 /var/www/html/wp-content

# Install Redis Object Cache plugin if not already installed
if ! ${WP_CLI} plugin list | grep -q 'redis-cache'; then
    echo "[*] Installing Redis Object Cache plugin..."
    ${WP_CLI} plugin install redis-cache --activate
fi

# Enable Redis object cache
echo "[*] Enabling Redis object cache..."
${WP_CLI} redis enable 2>/dev/null || {
    echo "[!] Redis enable failed. Verify Redis container is running and accessible at redis:6379"
}

# Verify Redis is working
if ${WP_CLI} redis cli ping 2>/dev/null | grep -q PONG; then
    echo "[✓] Redis connection successful!"
    ${WP_CLI} redis info
else
    echo "[!] Redis not responding. Check connectivity."
fi

# Optional: set up common settings
echo "[*] Configuring WordPress settings..."

# Timezone (if not set)
${WP_CLI} option get timezone_string > /dev/null || \
    ${WP_CLI} option update timezone_string "UTC"

# Permalink structure (if not set)
${WP_CLI} option get permalink_structure > /dev/null || \
    ${WP_CLI} rewrite structure '/%postname%/' --hard

# Install recommended development plugins (dev only)
if [ "${ENVIRONMENT}" = "dev" ] || [ "${BUILD_ENV}" = "development" ]; then
    echo "[*] Installing development plugins..."
    ${WP_CLI} plugin install query-monitor wp-reset --activate 2>/dev/null || true
fi

echo "[✓] WordPress first-run setup complete!"
echo ""
echo "Next steps:"
echo "  1. Access WordPress at http://localhost:${WP_PORT:-8080}"
echo "  2. Log in and verify Redis Object Cache is enabled in Dashborad > Tools > Redis"
echo "  3. Configure your site and start developing!"
