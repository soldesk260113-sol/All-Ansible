#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Antigravity Ansible Bootstrap Script
# ═══════════════════════════════════════════════════════════════════════════
# 설명:
# 1. SSH 키 생성 및 모든 서버에 Root 키 배포 (sshpass 사용)
# 2. Ansible Bootstrap Playbook 실행 (root 권한 -> ansible 계정 생성)
# 3. 인벤토리 및 기본 접속 설정 검증
# ═══════════════════════════════════════════════════════════════════════════

# set -e

# 색상 변수
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[Step 1] SSH 키 배포 (Root Access 확보)${NC}"
echo "--------------------------------------------------------"
if [ -f "./allserver_distribute_sshkeys.sh" ]; then
    ./allserver_distribute_sshkeys.sh
else
    echo "Error: ./allserver_distribute_sshkeys.sh not found!"
    exit 1
fi

# [Step 2.5] Jenkins 컨테이너/프로세스 자동 감지 및 키 추출
echo -e "\n${BLUE}[Step 2.5] Jenkins SSH Key 자동 감지${NC}"
JENKINS_PID=$(pgrep -f "java.*jenkins" | head -n 1)
JENKINS_KEY=""

if [ -n "$JENKINS_PID" ]; then
    echo "Jenkins Process Found (PID: $JENKINS_PID)"
    # /proc/PID/root 를 통해 컨테이너/프로세스 내부 파일 시스템 접근
    KEY_PATH="/proc/$JENKINS_PID/root/var/jenkins_home/.ssh/id_rsa.pub"
    
    if [ -f "$KEY_PATH" ]; then
        JENKINS_KEY=$(cat "$KEY_PATH")
        echo "Jenkins Public Key Found: ${JENKINS_KEY:0:30}..."
    else
        echo "Warning: Jenkins Public Key not found at $KEY_PATH"
    fi
else
    echo "Warning: Jenkins process not found. Skipping Jenkins key authorization."
fi

echo -e "\n${BLUE}[Step 3] Ansible Bootstrap Playbook 실행 (Ansible User 생성)${NC}"
echo "--------------------------------------------------------"
# 주의: group_vars/all.yml의 ansible_user 변수 우선순위를 덮어쓰기 위해 -e "ansible_user=root" 필수
# Jenkins Key가 발견되면 추가 변수로 전달
cd ..
if [ -n "$JENKINS_KEY" ]; then
    ansible-playbook -i inventory.ini playbooks/00_bootstrap_ansible_user.yml \
        -e "ansible_user=root" \
        -e "jenkins_ssh_public_key='$JENKINS_KEY'"
else
    ansible-playbook -i inventory.ini playbooks/00_bootstrap_ansible_user.yml \
        -e "ansible_user=root"
fi

echo -e "\n${GREEN}✅ Bootstrap Complete!${NC}"
echo "이제 'ansible' 계정으로 모든 서버를 관리할 수 있습니다."
echo "메인 플레이북 실행: ansible-playbook site.yml"
