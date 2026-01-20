#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# VM SSH 키 배포 스크립트 (ansible → ansible) - Fixed Quoting
# ═══════════════════════════════════════════════════════════════════════════

PASSWORD="ansible"  # ansible 계정 비밀번호
TARGET_USER="ansible"
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

echo "VM SSH 키 배포 (ansible → ansible)"

# Step 1: sshpass check
if ! command -v sshpass &> /dev/null; then
    sudo dnf install -y sshpass > /dev/null 2>&1
fi

# Step 2: Key generation
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
fi
PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

# Step 3: Distribution
SUCCESS_COUNT=0
FAIL_COUNT=0

for ip in "${SERVERS[@]}"; do
    printf "%-20s : " "$ip"
    
     # Base options
    SSH_OPTS=( 
        -o "StrictHostKeyChecking=no" 
        -o "UserKnownHostsFile=/dev/null" 
        -o "ConnectTimeout=10" 
    )

    if [[ "$ip" == 10.2.3.* ]]; then
         # Proxy options - note the quoting for the command string
        SSH_OPTS+=( -o "ProxyCommand=ssh -o StrictHostKeyChecking=no -W %h:%p -q ansible@$PROXY_HOST" )
    fi
    
    # Deploy Key
    if sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" "$TARGET_USER@$ip" "
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        grep -qF '$PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUB_KEY' >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        restorecon -R -v ~/.ssh 2>/dev/null || true
    " &>/dev/null; then
        # Verify
        if ssh "${SSH_OPTS[@]}" -o PasswordAuthentication=no -o PubkeyAuthentication=yes "$TARGET_USER@$ip" 'exit 0' &>/dev/null; then
            echo "✅ 성공"
            ((SUCCESS_COUNT++))
        else
            echo "⚠️  배포됨 (검증 실패)"
            ((SUCCESS_COUNT++))
        fi
    else
        echo "❌ 실패"
        ((FAIL_COUNT++))
    fi
done

echo "Done: $SUCCESS_COUNT success, $FAIL_COUNT failed"
