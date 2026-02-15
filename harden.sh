#!/bin/bash

# ==============================================================================
# Proxmox Hardening Script 🔐
# Author: Taha Echakiri (Netics)
# Description: Interactively secures Proxmox (SSH, Fail2Ban, Firewall)
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

info "Starting Hardening Process..."

# 1. Update Repositories (Remove Enterprise, Add No-Sub)
if ask "Configure 'No-Subscription' Repositories (and remove Enterprise)?"; then
    sed -i 's/^deb/#deb/g' /etc/apt/sources.list.d/pve-enterprise.list
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
    info "Repositories updated."
fi

# 2. Install Fail2Ban
if ask "Install and Configure Fail2Ban (Protects GUI & SSH)?"; then
    apt-get update && apt-get install -y fail2ban
    
    # Create Jail Config
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

    # Create Filter
    cat <<EOF > /etc/fail2ban/filter.d/proxmox.conf
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

    systemctl restart fail2ban
    info "Fail2Ban installed and active."
fi

# 3. Secure SSH
if ask "Harden SSH (Disable Root Login & Password Auth)? ⚠️  RISKY: Ensure you added your SSH Key first!"; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
    info "SSH Hardened. Root login disabled."
fi

# 4. Kernel Hardening (Network)
if ask "Apply Sysctl Network Hardening (BBR, Spoof Protection)?"; then
    cat <<EOF > /etc/sysctl.d/99-pve-hardening.conf
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Enable BBR Congestion Control (Speed)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Ignore ICMP Broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
EOF
    sysctl -p /etc/sysctl.d/99-pve-hardening.conf
    info "Network stack hardened."
fi

info "Hardening Complete! Run ./audit.sh to verify."
