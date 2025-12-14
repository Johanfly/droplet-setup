#!/bin/bash

# ============================================
# Cloudflare IP Auto-Update Script
# ============================================
# Script ini akan:
# 1. Download latest Cloudflare IPs
# 2. Update UFW rules otomatis
# 3. Jalankan via cron 1x per bulan
# ============================================

set -e

echo "🔄 Updating Cloudflare IP ranges..."

# Temporary files
IPV4_FILE="/tmp/cloudflare-ips-v4.txt"
IPV6_FILE="/tmp/cloudflare-ips-v6.txt"

# Download latest Cloudflare IPs
echo "📥 Downloading latest Cloudflare IP ranges..."
curl -s https://www.cloudflare.com/ips-v4 -o "$IPV4_FILE"
curl -s https://www.cloudflare.com/ips-v6 -o "$IPV6_FILE"

# Check if download successful
if [ ! -s "$IPV4_FILE" ] || [ ! -s "$IPV6_FILE" ]; then
    echo "❌ Failed to download Cloudflare IPs!"
    exit 1
fi

echo "✅ Download successful"

# Backup current UFW rules
echo "💾 Backing up current firewall rules..."
sudo cp /etc/ufw/user.rules "/etc/ufw/user.rules.backup.$(date +%Y%m%d)"

# Remove old Cloudflare rules ONLY (by comment tag)
echo "🗑️  Removing old Cloudflare rules..."
# Get all Cloudflare-tagged rules and delete them
CLOUDFLARE_RULES=$(sudo ufw status numbered | grep "Cloudflare" | awk '{print $1}' | sed 's/\[//;s/\]//' | sort -rn)

if [ -n "$CLOUDFLARE_RULES" ]; then
    echo "$CLOUDFLARE_RULES" | while read line; do
        if [ -n "$line" ]; then
            sudo ufw --force delete $line 2>/dev/null || true
        fi
    done
    echo "✅ Old Cloudflare rules removed"
else
    echo "ℹ️  No old Cloudflare rules found"
fi

# Add new IPv4 rules
echo "✅ Adding new IPv4 rules..."
while IFS= read -r ip; do
    sudo ufw allow from "$ip" to any port 80 proto tcp comment 'Cloudflare HTTP'
    sudo ufw allow from "$ip" to any port 443 proto tcp comment 'Cloudflare HTTPS'
done < "$IPV4_FILE"

# Add new IPv6 rules
echo "✅ Adding new IPv6 rules..."
while IFS= read -r ip; do
    sudo ufw allow from "$ip" to any port 80 proto tcp comment 'Cloudflare HTTP IPv6'
    sudo ufw allow from "$ip" to any port 443 proto tcp comment 'Cloudflare HTTPS IPv6'
done < "$IPV6_FILE"

# Reload UFW
echo "🔄 Reloading firewall..."
sudo ufw reload

# Cleanup
rm -f "$IPV4_FILE" "$IPV6_FILE"

echo ""
echo "✅ Cloudflare IPs updated successfully!"
echo "📊 Current rules:"
sudo ufw status numbered | grep -E "Cloudflare|ALLOW" | head -20

echo ""
echo "✅ Update completed at: $(date)"
