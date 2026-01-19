#!/bin/bash
# -------------------------------------------------------------------------
# [PC5 -> 전체 인프라] Firewalld 활성화 및 자동 시작 설정
# -------------------------------------------------------------------------

# 색상 변수
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# root 비밀번호
PASSWORD="centos"

# Proxy 호스트 설정 (10.2.3.x 접근용)
PROXY_HOST="10.2.2.20"

# 대상 서버 리스트 (내부 IP 기준)
SERVERS=(
    # [PC1]
    "10.2.1.1" "10.2.1.2" 
    # [PC2]
    "10.2.2.2" "10.2.2.3" "10.2.2.4"
    # [PC3]
    "10.2.2.5" "10.2.2.6" "10.2.2.7"
    # [PC6]
    "10.2.2.8" "10.2.2.9" "10.2.2.10"
    # [PC4]
    "10.2.2.20" "10.2.2.21" "10.2.2.30"
    "10.2.3.2" "10.2.3.3" "10.2.3.4"    # DB servers (via Proxy)
    "10.2.3.20" "10.2.3.21" "10.2.3.22" # etcd servers (via Proxy)
    # [PC5]
    "10.2.2.40" "10.2.2.50" "10.2.2.51" "10.2.2.60"
)

echo "========================================================"
echo " Firewalld 서비스 활성화 및 자동 시작 설정 (enable --now)"
echo "========================================================"

for ip in "${SERVERS[@]}"; do
    echo -n ">> Processing $ip ... "
    
    # 10.2.3.x 서브넷은 프록시 사용
    if [[ "$ip" == 10.2.3.* ]]; then
        SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=3 -o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -W %h:%p -q root@$PROXY_HOST\""
    else
        SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=3"
    fi
    
    # 1. Firewalld 켜기 및 자동 시작 설정
    # systemctl enable --now firewalld : 지금 즉시 켜고(Start), 재부팅 시 자동 실행(Enable) 설정
    sshpass -p "$PASSWORD" ssh $SSH_OPTS root@$ip \
    "systemctl enable --now firewalld" > /dev/null 2>&1
    
    # 2. 상태 확인
    sshpass -p "$PASSWORD" ssh $SSH_OPTS root@$ip "systemctl is-active firewalld" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[성공]${NC} Firewalld Running & Enabled"
    else
        echo -e "${RED}[실패]${NC} 접속 불가 또는 서비스 실행 실패"
    fi
done

echo "========================================================"
echo " 작업 완료. (주의: K8s 및 DB 포트 오픈 필요)"
echo "========================================================"
