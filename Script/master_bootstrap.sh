#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Master Bootstrap Script - 전체 인프라 초기화 및 연동 자동화
# ═══════════════════════════════════════════════════════════════════════════
# 실행: root 권한 필요
# 순서:
# 1. Ops 서버(PC5) 초기화 (패키지, Ansible 설치)
# 2. VM SSH 키 배포 (root -> root)
# 3. VM SSH 키 배포 (ansible -> ansible)
# 4. 방화벽 설정 (Firewalld Enable)
# 5. Jenkins SSH 키 배포 (Jenkins -> root)
# 6. Jenkins SSH 키 배포 (Jenkins -> ansible)
# 7. DB 서버 SSH 배포 (ssh_deploy.sh all-db)
# 8. 최종 Ping Test
# ═══════════════════════════════════════════════════════════════════════════

set -e  # 오류 발생 시 즉시 중단

LOG_FILE="/var/log/master_bootstrap.log"
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "==============================================================================="
echo "🚀 [Master Bootstrap] 전체 인프라 초기화를 시작합니다."
echo "   Start Time: $(date)"
echo "==============================================================================="

# 스크립트 디렉토리 이동
cd "$(dirname "$0")"

run_step() {
    local step_name="$1"
    local script_name="$2"
    local args="$3"

    echo ""
    echo "▶ [Step] $step_name 실행 중..."
    echo "   Command: ./$script_name $args"
    echo "-------------------------------------------------------------------------------"
    
    if [ -f "./$script_name" ]; then
        chmod +x "./$script_name"
        if ./$script_name $args; then
            echo "✅ [Step] $step_name 성공"
        else
            echo "❌ [Step] $step_name 실패!"
            exit 1
        fi
    else
        echo "❌ [Error] 스크립트 파일이 없습니다: $script_name"
        exit 1
    fi
    echo "-------------------------------------------------------------------------------"
}

# 1. PC5 초기화
run_step "PC5(Ops) 초기화 & Ansible 설치" "init_ops_ansible.sh" ""

# 2. VM SSH 키 배포 (Root)
run_step "Root SSH 키 배포 (root -> root)" "vm_distribute_ssh_root.sh" ""

# 3. VM SSH 키 배포 (Ansible)
run_step "Ansible SSH 키 배포 (ansible -> ansible)" "vm_distribute_ssh_ansible.sh" ""

# 4. 방화벽 활성화
run_step "전체 서버 Firewalld 활성화" "allserver_firewallon.sh" ""

# 5. Jenkins SSH 키 배포 (Root) - 주의: Jenkins 배포 후 실행해야 함
# echo "🚧 [Skip] Jenkins가 아직 배포되지 않았으므로 건너뜁니다."
# run_step "Jenkins SSH 키 배포 (Jenkins -> root)" "jenkins_distribute_ssh_root.sh" ""

# 6. Jenkins SSH 키 배포 (Ansible) - 주의: Jenkins 배포 후 실행해야 함
# echo "🚧 [Skip] Jenkins가 아직 배포되지 않았으므로 건너뜁니다."
# run_step "Jenkins SSH 키 배포 (Jenkins -> ansible)" "jenkins_distribute_ssh_ansible.sh" ""

# 7. DB 구성용 SSH 배포
# run_step "DB 서버 SSH 구성 (ssh_deploy.sh)" "ssh_deploy.sh" "all-db"

# 8. Ping Test
run_step "최종 연결 테스트 (Ping)" "pingtest.sh" ""

echo ""
echo "==============================================================================="
echo "🎉 [Success] 모든 초기화 작업이 완료되었습니다!"
echo "   End Time: $(date)"
echo "==============================================================================="
