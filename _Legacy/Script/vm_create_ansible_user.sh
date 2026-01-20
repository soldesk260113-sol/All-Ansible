#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Ansible User Creation Script (via Root) - Fixed Quoting
# ═══════════════════════════════════════════════════════════════════════════

PASSWORD="centos"    # root password
NEW_USER="ansible"
NEW_PASS="ansible"
PROXY_HOST="10.2.2.20"

SERVERS=(
    "172.16.6.61" "10.2.1.2"
    "10.2.2.2" "10.2.2.3" "10.2.2.4"
    "10.2.2.5" "10.2.2.6" "10.2.2.7"
    "10.2.2.8" "10.2.2.9" "10.2.2.10"
    "10.2.2.20" "10.2.2.21"
    "10.2.3.2" "10.2.3.3" "10.2.3.4"
    "10.2.3.20" "10.2.3.21" "10.2.3.22"
    "10.2.2.30"
    "10.2.2.40" "10.2.2.50" "10.2.2.51" "10.2.2.60"
)

echo "Creating '$NEW_USER' user on all nodes..."

for ip in "${SERVERS[@]}"; do
    printf "%-20s : " "$ip"
    
    # Base options
    SSH_OPTS=( 
        -o "StrictHostKeyChecking=no" 
        -o "UserKnownHostsFile=/dev/null" 
        -o "ConnectTimeout=10" 
    )

    if [[ "$ip" == 10.2.3.* ]]; then
        # Proxy options
        SSH_OPTS+=( -o "ProxyCommand=ssh -o StrictHostKeyChecking=no -W %h:%p -q root@$PROXY_HOST" )
    fi

    if sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" "root@$ip" "
        id -u $NEW_USER &>/dev/null || useradd $NEW_USER
        echo '$NEW_USER:$NEW_PASS' | chpasswd
        usermod -aG wheel $NEW_USER
        echo '$NEW_USER ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$NEW_USER
    " &>/dev/null; then
        echo "✅ Created/Verified"
    else
        echo "❌ Failed"
    fi
done
