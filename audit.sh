#!/bin/bash

# ==============================================================================
# Proxmox Security Audit Tool 🛡️
# Author: Taha Echakiri (Netics)
# Description: Checks Proxmox Node against common security best practices
# ==============================================================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCORE=0
TOTAL=0

function check() {
    DESC=$1
    CMD=$2
    EXPECTED=$3
    TOTAL=$((TOTAL+1))
    
    echo -n "Checking: $DESC... "
    RESULT=$(eval "$CMD")
    
    if [[ "$RESULT" == "$EXPECTED" ]]; then
        echo -e "${GREEN}PASS${NC}"
        SCORE=$((SCORE+1))
    else
        echo -e "${RED}FAIL${NC} (Found: $RESULT)"
    fi
}

function check_contains() {
    DESC=$1
    FILE=$2
    STRING=$3
    TOTAL=$((TOTAL+1))
    
    echo -n "Checking: $DESC... "
    if grep -q "$STRING" "$FILE" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        SCORE=$((SCORE+1))
    else
        echo -e "${RED}FAIL${NC}"
    fi
}

echo "=========================================="
echo "   Proxmox Security Audit (Netics)        "
echo "=========================================="

# 1. System Updates
check "Repositories (No Enterprise Repo without Sub)" \
    "grep -r 'pve-enterprise' /etc/apt/sources.list.d/ | grep -v '#' |  wc -l" \
    "0" 
# Note: This is subjective, but for homelab usually valid.

# 2. SSH Configuration
check_contains "SSH Root Login Disabled" "/etc/ssh/sshd_config" "^PermitRootLogin no"
check_contains "SSH Password Auth Disabled" "/etc/ssh/sshd_config" "^PasswordAuthentication no"

# 3. PVE Firewall
check "PVE Firewall Cluster-wide Enabled" \
    "grep 'enable: 1' /etc/pve/firewall/cluster.fw 2>/dev/null | head -1 | awk '{print \$2}'" \
    "1"

# 4. Fail2Ban
check "Fail2Ban Installed" \
    "dpkg -s fail2ban 2>/dev/null | grep Status | awk '{print \$4}'" \
    "installed"

check "Fail2Ban Active" \
    "systemctl is-active fail2ban" \
    "active"

# 5. Kernel Protection
check "BBR Congestion Control Enabled" \
    "sysctl net.ipv4.tcp_congestion_control | awk '{print \$3}'" \
    "bbr"

echo "=========================================="
echo "Security Score: $SCORE / $TOTAL"
if [ $SCORE -eq $TOTAL ]; then
    echo -e "${GREEN}EXCELLENT! System is hardened.${NC}"
else
    echo -e "${YELLOW}WARNING: Run ./harden.sh to fix issues.${NC}"
fi
echo "=========================================="
