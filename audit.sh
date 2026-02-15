#!/bin/bash

# ==============================================================================
# Proxmox Security Audit Tool v2.0 🛡️
# Author: Taha Echakiri (Netics)
# Description: Advanced CIS-based Security Audit for Proxmox VE
# ==============================================================================

# Colors & Formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

SCORE=0
TOTAL=0

function header() {
    echo -e "\n${BLUE}${BOLD}>>> $1${NC}"
}

function check() {
    DESC=$1
    CMD=$2
    EXPECTED=$3
    TOTAL=$((TOTAL+1))
    
    # Run command and trim whitespace
    RESULT=$(eval "$CMD" | tr -d '[:space:]')
    
    if [[ "$RESULT" == "$EXPECTED" ]]; then
        echo -e "${GREEN}✔ PASS${NC} : $DESC"
        SCORE=$((SCORE+1))
    else
        echo -e "${RED}✘ FAIL${NC} : $DESC (Found: ${RESULT:0:20}...)"
    fi
}

function check_contains() {
    DESC=$1
    FILE=$2
    STRING=$3
    TOTAL=$((TOTAL+1))
    
    if grep -q "$STRING" "$FILE" 2>/dev/null; then
        echo -e "${GREEN}✔ PASS${NC} : $DESC"
        SCORE=$((SCORE+1))
    else
        echo -e "${RED}✘ FAIL${NC} : $DESC"
    fi
}

clear
echo -e "${BOLD}=================================================="
echo -e "   PROXMOX SECURITY AUDIT v2.0 (Netics)"
echo -e "==================================================${NC}"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo -e "=================================================="

# --- 1. SYSTEM BASICS ---
header "1. System Basics"
check "No-Subscription Repo Configured" \
    "grep -r 'pve-no-subscription' /etc/apt/sources.list.d/ | wc -l" "1"

check "Enterprise Repo Disabled (unless sub)" \
    "grep -r 'pve-enterprise' /etc/apt/sources.list.d/ | grep -v '#' | wc -l" "0"

check "PVE Firewall Clustwide Enabled" \
    "grep 'enable: 1' /etc/pve/firewall/cluster.fw 2>/dev/null | head -1 | awk '{print \$2}'" "1"

check "Updates Pending" \
    "apt list --upgradable 2>/dev/null | grep -v Listing | wc -l" "0"

# --- 2. SSH HARDENING ---
header "2. SSH Configuration"
check_contains "SSH Protocol 2 Only" "/etc/ssh/sshd_config" "^Protocol 2"
check_contains "Root Login Disabled" "/etc/ssh/sshd_config" "^PermitRootLogin no"
check_contains "Password Auth Disabled" "/etc/ssh/sshd_config" "^PasswordAuthentication no"
check_contains "Empty Passwords Denied" "/etc/ssh/sshd_config" "^PermitEmptyPasswords no"
check_contains "Max Auth Tries <= 4" "/etc/ssh/sshd_config" "^MaxAuthTries [1-4]"
check_contains "X11 Forwarding Disabled" "/etc/ssh/sshd_config" "^X11Forwarding no"

# --- 3. NETWORK KERNEL TUNING ---
header "3. Network Kernel Tuning"
check "IP Forwarding Disabled (IPv4)" "sysctl net.ipv4.ip_forward | awk '{print \$3}'" "0"
check "ICMP Redirects Disabled" "sysctl net.ipv4.conf.all.accept_redirects | awk '{print \$3}'" "0"
check "BBR Congestion Control" "sysctl net.ipv4.tcp_congestion_control | awk '{print \$3}'" "bbr"
check "TCP SYN Cookies Enabled" "sysctl net.ipv4.tcp_syncookies | awk '{print \$3}'" "1"
check "Log Martians Enabled" "sysctl net.ipv4.conf.all.log_martians | awk '{print \$3}'" "1"

# --- 4. SERVICES & LOGGING ---
header "4. Services & Logging"
check "Fail2Ban Installed" \
    "dpkg -s fail2ban 2>/dev/null | grep Status | awk '{print \$4}'" "installed"

check "Fail2Ban Active" \
    "systemctl is-active fail2ban" "active"

check "Postfix Listening Local Only" \
    "netstat -plnt | grep :25 | grep '127.0.0.1' | wc -l" "1"

check "Systemd Journal Persistent" \
    "grep '^Storage=persistent' /etc/systemd/journald.conf | wc -l" "1"

# --- 5. FILESYSTEM & PERMISSIONS ---
header "5. Host Filesystem"
check "/tmp is on separate partition" \
    "mount | grep ' /tmp ' | wc -l" "1"

check "/var/tmp is bound to /tmp" \
    "mount | grep ' /var/tmp ' | wc -l" "1"

check "Shadow File Perms (0640)" \
    "stat -c %a /etc/shadow" "640"

check "Passwd File Perms (0644)" \
    "stat -c %a /etc/passwd" "644"

# --- 6. USER SAFETY ---
header "6. User Safety"
check "No UID 0 Users except Root" \
    "awk -F: '(\$3 == 0) {print}' /etc/passwd | wc -l" "1"

check "Root Path Integrity" \
    "echo \$PATH | grep '::'" "" # Should be empty

echo -e "\n=================================================="
PERCENT=$((SCORE * 100 / TOTAL))
if [ $PERCENT -ge 90 ]; then COLOR=$GREEN; elif [ $PERCENT -ge 70 ]; then COLOR=$YELLOW; else COLOR=$RED; fi
echo -e "FINAL SCORE: ${COLOR}$SCORE / $TOTAL ($PERCENT%)${NC}"
echo -e "=================================================="
if [ $PERCENT -lt 100 ]; then
    echo -e "${YELLOW}👉 Run ./harden.sh to select issues to fix.${NC}"
fi
