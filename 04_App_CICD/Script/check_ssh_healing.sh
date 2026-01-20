#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# SSH 연결 자가 치유 (Self-Healing) 스크립트
# ═══════════════════════════════════════════════════════════════════════════
# 용도: Jenkins 파이프라인 시작 전 실행하여 SSH 연결 문제 자동 복구
# 작동 방식:
#   1. Jenkins 컨테이너에서 Ansible Ping으로 연결 확인
#   2. 실패한 서버 감지
#   3. 실패한 서버에 대해 SSH 키 재배포 스크립트 실행
#   4. 재확인
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(dirname "$0")"
JENKINS_CONTAINER="jenkins"
WORKSPACE_DIR="/var/jenkins_home/workspace/Ansible-Pipeline"
INVENTORY_FILE="inventory.ini"

echo "═══════════════════════════════════════════════════════════════════════════"
echo "🚑 SSH 연결 자가 치유 (Self-Healing) 시작"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# 1. Jenkins 컨테이너 확인
if ! docker ps | grep -q "$JENKINS_CONTAINER"; then
    echo "❌ Jenkins 컨테이너가 실행 중이 아닙니다."
    exit 1
fi

# 2. 연결 확인 (Ping)
echo "[1/3] Ansible 연결 상태 점검 중..."
PING_OUTPUT=$(docker exec $JENKINS_CONTAINER bash -c "cd $WORKSPACE_DIR && ansible -i $INVENTORY_FILE all -m ping" 2>&1)

# 실패한 호스트 IP 추출
# UNREACHABLE! 에러가 발생한 IP를 추출 (정규식으로 IP 패턴 매칭)
FAILED_HOSTS=$(echo "$PING_OUTPUT" | grep -B 1 "UNREACHABLE!" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq)

if [ -z "$FAILED_HOSTS" ]; then
    echo "✅ 모든 서버 연결 상태: 정상"
    echo "   별도의 조치가 필요하지 않습니다."
    exit 0
else
    echo "⚠️  다음 서버들에 연결할 수 없습니다:"
    echo "$FAILED_HOSTS"
    echo ""
fi

# 3. 자동 복구 시도
echo "[2/3] 자동 복구 시도 (SSH 키 재배포)..."
# 배열로 변환
HOSTS_ARRAY=($FAILED_HOSTS)

# 복구 스크립트 실행 (실패한 호스트들만 전달)
echo "   대상: ${HOSTS_ARRAY[*]}"
bash "$SCRIPT_DIR/jenkins_distribute_ssh_ansible.sh" "${HOSTS_ARRAY[@]}"

RECOVERY_EXIT_CODE=$?

if [ $RECOVERY_EXIT_CODE -ne 0 ]; then
    echo "❌ 복구 스크립트 실행 중 오류가 발생했습니다."
    # 치명적인 오류는 아님 (일부 서버가 오프라인일 수 있음)
fi
echo ""

# 4. 결과 재확인
echo "[3/3] 복구 결과 확인..."
RETRY_OUTPUT=$(docker exec $JENKINS_CONTAINER bash -c "cd $WORKSPACE_DIR && ansible -i $INVENTORY_FILE all -m ping" 2>&1)
FINAL_FAILED_HOSTS=$(echo "$RETRY_OUTPUT" | grep -B 1 "UNREACHABLE!" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq)

if [ -z "$FINAL_FAILED_HOSTS" ]; then
    echo "✨ 모든 연결 문제가 해결되었습니다!"
    exit 0
else
    echo "❌ 여전히 다음 서버들에 연결할 수 없습니다:"
    echo "$FINAL_FAILED_HOSTS"
    echo "   서버가 오프라인인지 또는 네트워크 문제가 있는지 확인하세요."
    # 오프라인 서버가 있어도 파이프라인을 계속 진행할지 여부는 Jenkinsfile에서 결정
    # 여기서는 실패 코드 반환
    exit 1
fi
