#!/bin/bash

# ==============================================================================
# Proxmox Hardening Script v2.0 🔐
# Author: Taha Echakiri (Netics)
# Description: Interactive Hardening for Proxmox VE (Safety First)
# ==============================================================================

set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function info() { echo -e "${GREEN}[INFO] $1${NC}"; }
function ask() {
    read -p "$(echo -e "${YELLOW}[?] $1 (y/n): ${NC}")" choice
    case "$choice" in 
        y|Y ) return 0 ;;
        * ) return 1 ;;
    esac
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "=========================================="
echo "   PROXMOX HARDENING v2.0 (Netics)"
echo "=========================================="

# --- 1. REPOSITORIES ---
if ask "1. Configure 'No-Subscription' Repos & Disable Enterprise?"; then
    sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
    info "Repositories updated."
fi

# --- 2. FAIL2BAN ---
if ask "2. Install & Configure Fail2Ban (WebUI + SSH)?"; then
    apt-get update && apt-get install -y fail2ban
    
    # Jail
    cat <<EOF > /etc/fail2ban/jail.local
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 3
findtime = 600
bantime = 3600

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

    # Filter
    cat <<EOF > /etc/fail2ban/filter.d/proxmox.conf
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

    systemctl restart fail2ban
    info "Fail2Ban active."
fi

# --- 3. SSH ---
if ask "3. HARDEN SSH (Disable Root & Password Login)? ⚠️  RISK: LOCKOUT!"; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Apply changes
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    sed -i 's/^X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    
    # Add MaxTries
    if ! grep -q "MaxAuthTries" /etc/ssh/sshd_config; then
        echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
    fi
    
    systemctl restart sshd
    info "SSH Hardened."
fi

# --- 4. KERNEL & NETWORK ---
if ask "4. Apply Kernel Network Hardening (BBR, Spoof Protection)?"; then
    cat <<EOF > /etc/sysctl.d/99-pve-hardening.conf
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP Broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Enable BBR Congestion Control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP Hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
EOF
    sysctl -p /etc/sysctl.d/99-pve-hardening.conf
    info "Kernel parameters applied."
fi

# --- 5. SYSTEM SERVICES ---
if ask "5. Disable IPv6 (if not used)?"; then
    cat <<EOF >> /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
    info "IPv6 Disabled."
fi

info "Hardening Complete. Run ./audit.sh to verify."
