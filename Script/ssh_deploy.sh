#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# SSH Key Deployment & Configuration Utility
# ═══════════════════════════════════════════════════════════════════════════
# Usage:
#   ./ssh_deploy.sh <mode> [target]
#
# Modes:
#   single <IP>           - Deploy host SSH key to single server
#   db-fix                - Deploy host SSH key to DB servers (via ProxyJump)
#   db-sudo               - Configure passwordless sudo on DB servers
#   jenkins-to-db         - Deploy Jenkins container key to DB servers
#   all-db                - Run all DB fixes (keys + sudo + jenkins)
# ═══════════════════════════════════════════════════════════════════════════

# set -e

PASSWORD="${SSH_PASSWORD:-centos}"
PROXY_HOST="10.2.2.20"
DB_SERVERS=("10.2.3.2" "10.2.3.3")

# ═══════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════

deploy_key_to_single() {
    local IP=$1
    local PUB_KEY=$(cat ~/.ssh/id_rsa.pub)
    local SSH_OPTS=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null" "-o" "ConnectTimeout=10")
    
    echo "📦 Deploying SSH key to $IP..."
    
    # Deploy to root
    sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" root@$IP \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF \"$PUB_KEY\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUB_KEY\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh 2>/dev/null || true"
    [ $? -eq 0 ] && echo "  ✅ Root: OK" || echo "  ❌ Root: FAIL"
    
    # Deploy to ansible user
    sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" ansible@$IP \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF \"$PUB_KEY\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUB_KEY\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh 2>/dev/null || true"
    [ $? -eq 0 ] && echo "  ✅ Ansible: OK" || echo "  ❌ Ansible: FAIL"
}

deploy_key_to_db_via_proxy() {
    local PUB_KEY=$(cat ~/.ssh/id_rsa.pub)
    local PROXY_CMD="ssh -o StrictHostKeyChecking=no -W %h:%p -q root@$PROXY_HOST"
    
    echo "📦 Deploying SSH key to DB servers (via ProxyJump)..."
    
    for IP in "${DB_SERVERS[@]}"; do
        echo "  → $IP"
        sshpass -p "$PASSWORD" ssh -o ProxyCommand="$PROXY_CMD" -o StrictHostKeyChecking=no root@$IP \
            "mkdir -p /home/ansible/.ssh && echo \"$PUB_KEY\" >> /home/ansible/.ssh/authorized_keys && chown -R ansible:ansible /home/ansible/.ssh && chmod 700 /home/ansible/.ssh && chmod 600 /home/ansible/.ssh/authorized_keys && restorecon -R -v /home/ansible/.ssh 2>/dev/null || true"
        [ $? -eq 0 ] && echo "    ✅ SUCCESS" || echo "    ❌ FAIL"
    done
}

configure_db_sudo() {
    local PROXY_CMD="ssh -o StrictHostKeyChecking=no -W %h:%p -q root@$PROXY_HOST"
    
    echo "🔧 Configuring passwordless sudo on DB servers..."
    
    for IP in "${DB_SERVERS[@]}"; do
        echo "  → $IP"
        sshpass -p "$PASSWORD" ssh -o ProxyCommand="$PROXY_CMD" -o StrictHostKeyChecking=no root@$IP \
            "echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible && chmod 440 /etc/sudoers.d/ansible"
        [ $? -eq 0 ] && echo "    ✅ SUCCESS" || echo "    ❌ FAIL"
    done
}

deploy_jenkins_key_to_db() {
    if ! docker ps | grep -q jenkins; then
        echo "❌ Jenkins container not running!"
        exit 1
    fi
    
    local JENKINS_KEY=$(docker exec jenkins cat /root/.ssh/id_rsa.pub 2>/dev/null)
    if [ -z "$JENKINS_KEY" ]; then
        echo "❌ Failed to get Jenkins SSH key!"
        exit 1
    fi
    
    local PROXY_CMD="ssh -o StrictHostKeyChecking=no -W %h:%p -q root@$PROXY_HOST"
    
    echo "🐳 Deploying Jenkins container SSH key to DB servers..."
    echo "Jenkins Key: ${JENKINS_KEY:0:50}..."
    echo ""
    
    for IP in "${DB_SERVERS[@]}"; do
        echo "  → $IP"
        sshpass -p "$PASSWORD" ssh -o ProxyCommand="$PROXY_CMD" -o StrictHostKeyChecking=no root@$IP \
            "grep -qF \"$JENKINS_KEY\" /home/ansible/.ssh/authorized_keys 2>/dev/null || echo \"$JENKINS_KEY\" >> /home/ansible/.ssh/authorized_keys && chmod 600 /home/ansible/.ssh/authorized_keys && chown ansible:ansible /home/ansible/.ssh/authorized_keys"
        [ $? -eq 0 ] && echo "    ✅ SUCCESS" || echo "    ❌ FAIL"
    done
    
    echo ""
    echo "🔍 Verification: Testing Jenkins container SSH access..."
    for IP in "${DB_SERVERS[@]}"; do
        docker exec jenkins ssh -o ProxyCommand='ssh -W %h:%p -q root@10.2.2.20' -o StrictHostKeyChecking=no ansible@$IP 'echo "  ✅ '$IP': OK"' 2>/dev/null || echo "  ❌ $IP: FAIL"
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# Main Logic
# ═══════════════════════════════════════════════════════════════════════════

MODE=${1:-}
TARGET=${2:-}

case "$MODE" in
    single)
        if [ -z "$TARGET" ]; then
            echo "Usage: $0 single <IP>"
            exit 1
        fi
        deploy_key_to_single "$TARGET"
        ;;
    
    db-fix)
        deploy_key_to_db_via_proxy
        ;;
    
    db-sudo)
        configure_db_sudo
        ;;
    
    jenkins-to-db)
        deploy_jenkins_key_to_db
        ;;
    
    all-db)
        echo "═══════════════════════════════════════════════════════════════"
        echo "Running ALL DB server fixes..."
        echo "═══════════════════════════════════════════════════════════════"
        deploy_key_to_db_via_proxy
        echo ""
        configure_db_sudo
        echo ""
        deploy_jenkins_key_to_db
        echo ""
        echo "✅ All DB fixes completed!"
        ;;
    
    *)
        echo "Usage: $0 <mode> [target]"
        echo ""
        echo "Modes:"
        echo "  single <IP>      - Deploy host SSH key to single server"
        echo "  db-fix           - Deploy host SSH key to DB servers (via ProxyJump)"
        echo "  db-sudo          - Configure passwordless sudo on DB servers"
        echo "  jenkins-to-db    - Deploy Jenkins container key to DB servers"
        echo "  all-db           - Run all DB fixes (keys + sudo + jenkins)"
        exit 1
        ;;
esac
