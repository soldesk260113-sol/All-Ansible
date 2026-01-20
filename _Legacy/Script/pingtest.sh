#!/bin/bash
# -------------------------------------------------------------------------
# [PC5 -> 전체 인프라] 네트워크 상태 점검 (Ping Test)
# 설정: 3회 테스트 (ICMP), 응답 없을 시 [불량] 처리
# 10.2.3.x 대역은 SSH를 통한 원격 ping 실행 (Proxy 경유)
# bash pingtest.sh로 실행 / . pingtest.sh로 실행시 타임 아웃 에러 발생
# -------------------------------------------------------------------------

# 색상 변수 설정 (시각적 확인 용도)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Proxy 호스트 설정 (10.2.3.x 접근용)
PROXY_HOST="10.2.2.20"  # DB-Proxy1
PROXY_USER="root"       # root 사용자 (더 안정적)
PROXY_PASSWORD="centos" # root 사용자 비밀번호

# sshpass 설치 확인
if ! command -v sshpass &> /dev/null; then
    echo "⚠️  sshpass가 설치되어 있지 않습니다. 설치 중..."
    sudo dnf install -y sshpass > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ sshpass 설치 완료"
    else
        echo "❌ sshpass 설치 실패. 10.2.3.x 대역 테스트를 건너뜁니다."
    fi
fi

# 점검 대상 IP 리스트 (내부망 IP 기준)
SERVERS=(
    # [PC1] Gateway / WAF / DNS
    "10.2.1.1"  # FW (Internal Gateway) - 172.16.6.61
    "10.2.1.2"  # WAF

    # [PC2] K8S Control Plane
    "10.2.2.2"  # CP1
    "10.2.2.3"  # CP2
    "10.2.2.4"  # CP3

    # [PC3] K8S Worker Node Set A
    "10.2.2.5"  # Worker1
    "10.2.2.6"  # Worker2
    "10.2.2.7"  # Worker3

    # [PC6] K8S Worker Node Set B
    "10.2.2.8"  # Worker4
    "10.2.2.9"  # Worker5
    "10.2.2.10" # Worker6

    # [PC4] DB & Storage
    "10.2.2.20" # DB Proxy 1
    "10.2.2.21" # DB Proxy 2
    "10.2.2.30" # Storage
    "10.2.3.2"  # DB Active (주의: 라우팅 없으면 불량 뜰 수 있음)
    "10.2.3.3"  # DB Standby
    "10.2.3.4"  # DB Backup
    "10.2.3.20" # DB etcd_1
    "10.2.3.21" # DB etcd_2
    "10.2.3.22" # DB etcd_3

    # [PC5] Ops (주변 서버)
    "10.2.2.40" # Ansible/CICD
    "10.2.2.50" # Monitoring1
    "10.2.2.51" # Monitoring2
    "10.2.2.60"  # DNS
)

echo "========================================================"
echo " 네트워크 연결 상태 점검 시작 (Target: ${#SERVERS[@]} hosts)"
echo "--------------------------------------------------------"
echo " * 테스트 방식 : ICMP Ping 3회 발송"
echo " * 10.2.3.x 대역 : SSH 원격 Ping (via $PROXY_HOST)"
echo " * 타임 아웃 : 1초 (빠른 확인)"
echo "========================================================"

# 카운터 변수
SUCCESS_COUNT=0
FAIL_COUNT=0

for ip in "${SERVERS[@]}"; do
    # 10.2.3.x 대역은 SSH를 통한 원격 ping 실행
    if [[ "$ip" == 10.2.3.* ]]; then
        # Proxy 호스트에서 원격으로 ping 실행 (sshpass 사용, root 계정)
        # -o StrictHostKeyChecking=no : 호스트 키 확인 생략
        # -o ConnectTimeout=5 : SSH 연결 타임아웃 5초
        # SSH 경고 메시지만 숨기고, ping 결과는 제대로 반환되도록 함
        sshpass -p "$PROXY_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR $PROXY_USER@$PROXY_HOST \
            "ping -c 3 -W 1 $ip > /dev/null 2>&1"
    else
        # 일반 대역은 직접 ping
        # ping -c 3 : 3번 보냄
        # -W 1 : 1초 대기 (응답 없으면 빠르게 넘김)
        # > /dev/null : 지저분한 로그 숨김
        ping -c 3 -W 1 "$ip" > /dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[정상]${NC} $ip : 연결 양호"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}[불량]${NC} $ip : 응답 없음 (Check Network/Firewall)"
        ((FAIL_COUNT++))
    fi
done

echo "========================================================"
echo -e " 점검 완료"
echo -e " - 정상 연결 : ${GREEN}${SUCCESS_COUNT}${NC} 대"
echo -e " - 연결 불량 : ${RED}${FAIL_COUNT}${NC} 대"
echo "========================================================"
