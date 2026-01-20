#!/bin/bash
# 모니터링 서버 이중화(Keepalived) 상태 확인 스크립트

VIP="10.2.2.99"
MASTER="10.2.2.50"
BACKUP="10.2.2.51"

echo "========================================================"
echo " 📡 모니터링 서버 이중화(HA) 상태 점검"
echo "========================================================"

# 1. VIP 소유 확인
echo -e "\n[1] VIP($VIP) 소유 노드 확인:"

check_vip() {
    local host=$1
    local name=$2
    if ssh -o StrictHostKeyChecking=no -q root@$host "ip addr | grep -q $VIP"; then
        echo " ✅ $name ($host): VIP를 보유하고 있습니다. (Active)"
        return 0
    else
        echo "    $name ($host): Standby 상태입니다."
        return 1
    fi
}

check_vip $MASTER "Monitoring (Master)"
MASTER_HAS_VIP=$?
check_vip $BACKUP "Monitoring (Backup)"
BACKUP_HAS_VIP=$?

if [ $MASTER_HAS_VIP -eq 1 ] && [ $BACKUP_HAS_VIP -eq 1 ]; then
    echo " ❌ 경고: 어느 노드도 VIP를 가지고 있지 않습니다!"
elif [ $MASTER_HAS_VIP -eq 0 ] && [ $BACKUP_HAS_VIP -eq 0 ]; then
    echo " ❌ 위험: Split-Brain 의심! 두 노드 모두 VIP를 가지고 있습니다."
fi

# 2. 서비스 응답 확인
echo -e "\n[2] VIP($VIP)를 통한 서비스 응답 확인:"

check_service() {
    local port=$1
    local name=$2
    
    # 3초 타임아웃
    http_code=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 3 http://$VIP:$port)
    
    if [ "$http_code" == "200" ] || [ "$http_code" == "302" ]; then
        echo " ✅ $name ($port): 정상 (HTTP $http_code)"
    else
        echo " ❌ $name ($port): 실패 (HTTP $http_code)"
    fi
}

check_service 3000 "Grafana"
check_service 9090 "Prometheus"
check_service 9093 "Alertmanager"

echo "========================================================"
