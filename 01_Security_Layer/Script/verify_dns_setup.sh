#!/bin/bash
# 내부 DNS (BIND) 구축 상태 및 전체 레코드 검증 스크립트
# 실행 위치: Ansible Controller (PC5) -> Target: DNS Server (10.2.2.60)

DNS_SERVER="10.2.2.60"

echo "========================================================"
echo " 🌐 내부 DNS (BIND) 전체 레코드 검증 ($DNS_SERVER)"
echo "========================================================"

# SSH를 통해 원격 DNS 서버에서 검증 로직 실행
ssh -T -o StrictHostKeyChecking=no root@$DNS_SERVER << 'EOF'

# ----------------------------------------------------
# Remote Script Start
# ----------------------------------------------------

# 테스트할 전체 레코드 목록 (roles/dns/vars/main.yml 기반)
declare -A TEST_RECORDS

# [Zone: core.internal]
TEST_RECORDS["secure.core.internal"]="10.2.1.1"
TEST_RECORDS["waf.core.internal"]="10.2.1.2"
TEST_RECORDS["dns.core.internal"]="10.2.2.60"

# [Zone: k8s.internal]
TEST_RECORDS["k8s-api.k8s.internal"]="10.2.2.100"
TEST_RECORDS["cp1.k8s.internal"]="10.2.2.2"
TEST_RECORDS["cp2.k8s.internal"]="10.2.2.3"
TEST_RECORDS["cp3.k8s.internal"]="10.2.2.4"
TEST_RECORDS["wk1.k8s.internal"]="10.2.2.5"
TEST_RECORDS["wk2.k8s.internal"]="10.2.2.6"
TEST_RECORDS["wk3.k8s.internal"]="10.2.2.7"
TEST_RECORDS["wk4.k8s.internal"]="10.2.2.8"
TEST_RECORDS["wk5.k8s.internal"]="10.2.2.9"
TEST_RECORDS["wk6.k8s.internal"]="10.2.2.10"

# [Zone: db.internal]
TEST_RECORDS["db-vip.db.internal"]="10.2.2.254"
TEST_RECORDS["db-proxy1.db.internal"]="10.2.2.20"
TEST_RECORDS["db-proxy2.db.internal"]="10.2.2.21"
TEST_RECORDS["storage.db.internal"]="10.2.2.30"
TEST_RECORDS["db-internal.db.internal"]="10.2.3.254"
TEST_RECORDS["db-a.db.internal"]="10.2.3.2"
TEST_RECORDS["db-s.db.internal"]="10.2.3.3"
TEST_RECORDS["db-b.db.internal"]="10.2.3.4"
TEST_RECORDS["etcd-1.db.internal"]="10.2.3.20"
TEST_RECORDS["etcd-2.db.internal"]="10.2.3.21"
TEST_RECORDS["etcd-3.db.internal"]="10.2.3.22"

# [Zone: svc.internal]
TEST_RECORDS["ingress.svc.internal"]="10.2.1.2"

# [Zone: ops.internal]
TEST_RECORDS["ci.ops.internal"]="10.2.2.40"
TEST_RECORDS["mon.ops.internal"]="10.2.2.50"

# [Zone: edge.internal]
TEST_RECORDS["edge.edge.internal"]="10.2.1.2"
TEST_RECORDS["rp1.edge.internal"]="10.2.1.2"


GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n[1] BIND 서비스 상태 확인:"
if systemctl is-active --quiet named; then
    echo -e "${GREEN} ✅ Named (BIND) Service is Running.${NC}"
else
    echo -e "${RED} ❌ Named Service is NOT Running!${NC}"
    exit 1
fi

echo -e "\n[2] 내부 도메인 전체 조회 테스트 (총 ${#TEST_RECORDS[@]}개 레코드):"
FAIL_COUNT=0
SUCCESS_COUNT=0

# 정렬된 출력을 위해 키만 추출해서 정렬 가능하나, bash에서는 복잡하니 그냥 Loop
for fqdn in "${!TEST_RECORDS[@]}"; do
    expected_ip="${TEST_RECORDS[$fqdn]}"
    # Localhost(127.0.0.1)에게 질의
    result=$(dig @127.0.0.1 +short $fqdn 2>/dev/null)
    
    if [ "$result" == "$expected_ip" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        # 너무 많으니 성공은 간략히 (한 줄에 여러 개 찍거나, 또는 생략하고 실패만 강조 가능)
        # 여기서는 상세히 보여주되 정렬이 안되어 있음.
        printf "   %-30s -> ${GREEN}%-15s${NC} [OK]\n" "$fqdn" "$result"
    else
        echo -e "   ${RED}[FAIL] $fqdn${NC} -> Expected: $expected_ip, Got: '$result'"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
done

echo -e "\n--------------------------------------------------------"
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN} 🎉 모든 레코드($SUCCESS_COUNT개) 조회 성공!${NC}"
else
    echo -e "${RED} ⚠️ 총 $FAIL_COUNT개 레코드 조회 실패.${NC}"
fi

echo -e "\n[3] 외부 도메인 재귀 조회 (Forwarding):"
ext_result=$(dig @127.0.0.1 +short google.com 2>/dev/null)
if [ -n "$ext_result" ]; then
    echo -e "${GREEN} ✅ Forwarding Works: google.com -> $ext_result${NC}"
else
    echo -e "${RED} ❌ Forwarding Failed${NC}"
fi

# ----------------------------------------------------
# Remote Script End
# ----------------------------------------------------
EOF

echo "========================================================"
echo " 검증 완료."
echo "========================================================"
