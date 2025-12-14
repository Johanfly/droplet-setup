#!/bin/bash
# Tunggu sampai IP Tailscale tersedia (max 60 detik)
for i in {1..60}; do
    if tailscale status &>/dev/null && ip addr show tailscale0 2>/dev/null | grep -q "inet 100."; then
        echo "Tailscale ready with IP"
        exit 0
    fi
    sleep 1
done
echo "Tailscale IP not available after 60s"
exit 1
