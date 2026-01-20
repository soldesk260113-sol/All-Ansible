#!/bin/bash
# PC5(Ops) 서버 초기화 및 Ansible 자동 설치 스크립트
# 실행: root 권한 필요 (또는 sudo)

echo "===================================================="
echo "[1/5] 시스템 업데이트 및 기본 설정"
echo "===================================================="
# SELinux 관련 라이브러리 및 EPEL/CRB
dnf install -y epel-release
dnf config-manager --set-enabled crb || true
dnf makecache

echo "===================================================="
echo "[2/5] 필수 패키지 및 Ansible Core 설치"
echo "===================================================="
dnf install -y \
  ansible-core \
  python3-pip \
  git \
  vim \
  openssh-clients \
  sshpass \
  rsync \
  python3-libselinux

# pip 업그레이드
pip3 install --upgrade pip

echo "===================================================="
echo "[3/5] Ansible 컬렉션 및 추가 패키지 설치"
echo "===================================================="
# RPM으로 제공되는 컬렉션 설치 (안정성)
dnf install -y ansible-collection-ansible-posix
dnf install -y ansible-collection-community-general

# Galaxy를 통한 최신/추가 컬렉션 설치
ansible-galaxy collection install community.postgresql ansible.posix community.general

echo "===================================================="
echo "[4/5] SSH 키 생성 및 배포 (Self)"
echo "===================================================="
# 키가 없을 때만 생성
if [ ! -f /root/.ssh/id_ed25519_ansible ]; then
    echo "SSH 키 생성 중..."
    ssh-keygen -t ed25519 -a 64 -f /root/.ssh/id_ed25519_ansible -N "" -C "proxy1-ansible"
else
    echo "SSH 키가 이미 존재합니다."
fi

# 자기 자신(10.2.2.40)에게 키 복사 (비밀번호 입력이 필요할 수 있으므로 주의, sshpass 사용 권장하나 여기선 ssh-copy-id 원본 유지)
# 단, 자동화를 위해 sshpass 시도
if command -v sshpass &> /dev/null; then
    echo "sshpass를 사용하여 키 복사 시도..."
    sshpass -p "centos" ssh-copy-id -i /root/.ssh/id_ed25519_ansible.pub -o StrictHostKeyChecking=no root@10.2.2.40
else
    ssh-copy-id -i /root/.ssh/id_ed25519_ansible.pub root@10.2.2.40
fi

echo "===================================================="
echo "Ansible 설치 및 초기화 완료!"
ansible --version
echo "===================================================="
