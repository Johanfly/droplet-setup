#!/bin/bash

# ============================================
# Cloudflare Firewall Setup Script
# ============================================
# Script ini akan:
# 1. Block semua traffic ke port 80/443
# 2. Hanya allow traffic dari Cloudflare IPs
# ============================================

set -e

echo "🔒 Setting up Cloudflare-only firewall..."
echo ""
echo "⚠️  CURRENT UFW STATUS:"
sudo ufw status numbered
echo ""
echo "📋 IMPORTANT:"
echo "   Script ini HANYA akan menambahkan rules Cloudflare"
echo "   Script TIDAK akan menghapus rules yang sudah ada"
echo ""
echo "⚠️  Anda HARUS HAPUS MANUAL rules berikut SEBELUM menjalankan script ini:"
echo "   - 'Nginx Full' atau '80,443/tcp (Nginx Full)'"
echo "   - Rules yang allow port 80/443 from 'Anywhere'"
echo ""
echo "📖 Cara hapus manual:"
echo "   1. Lihat nomor rule: sudo ufw status numbered"
echo "   2. Hapus by nomor: sudo ufw delete [nomor]"
echo ""
read -p "Apakah Anda sudah hapus manual rules port 80/443 yang lama? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "❌ Aborted. Silakan hapus rules manual dulu, lalu jalankan script lagi"
    echo ""
    echo "Contoh:"
    echo "  sudo ufw status numbered"
    echo "  sudo ufw delete 2  # ganti dengan nomor rule yang benar"
    exit 1
fi

echo ""
echo "✅ Lanjut menambahkan Cloudflare rules..."
echo ""

# ============================================
# 2. ALLOW CLOUDFLARE IPs ONLY (Port 80/443)
# ============================================
echo "✅ Adding Cloudflare IPv4 ranges..."

# Cloudflare IPv4 ranges (Updated Dec 2025)
# Source: https://www.cloudflare.com/ips-v4
CLOUDFLARE_IPS=(
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
)

for ip in "${CLOUDFLARE_IPS[@]}"; do
    sudo ufw allow from $ip to any port 80 proto tcp comment 'Cloudflare HTTP'
    sudo ufw allow from $ip to any port 443 proto tcp comment 'Cloudflare HTTPS'
done

# Cloudflare IPv6 ranges
echo "✅ Adding Cloudflare IPv6 ranges..."
CLOUDFLARE_IPV6=(
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
)

for ip in "${CLOUDFLARE_IPV6[@]}"; do
    sudo ufw allow from $ip to any port 80 proto tcp comment 'Cloudflare HTTP IPv6'
    sudo ufw allow from $ip to any port 443 proto tcp comment 'Cloudflare HTTPS IPv6'
done

# ============================================
# 3. ALLOW LOCALHOST
# ============================================
echo "✅ Allowing localhost..."
sudo ufw allow from 127.0.0.1 comment 'Localhost'

# ============================================
# 4. RELOAD FIREWALL (already enabled)
# ============================================
echo "🔄 Reloading UFW firewall..."
sudo ufw reload

# ============================================
# 5. SHOW STATUS
# ============================================
echo ""
echo "✅ Firewall configured successfully!"
echo ""
echo "📊 Current firewall status:"
sudo ufw status numbered

echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   1. Port 80/443 HANYA bisa diakses dari Cloudflare"
echo "   2. User tetap bisa akses web via Cloudflare"
echo "   3. Direct access ke VPS IP akan di-block"
echo ""