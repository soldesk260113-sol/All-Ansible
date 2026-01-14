# 🏗️ Antigravity Infrastructure (Ansible)

**Antigravity** 프로젝트의 전체 인프라 자동화를 위한 Ansible 저장소입니다.  
네트워크, Kubernetes(K8s), 모니터링, DB, 보안, CI/CD 설정까지 모든 구성을 코드로 관리(IaC)합니다.

---

## 🌍 1. 서버 구성 (Server Topology)

총 **23대**의 VM으로 구성된 멀티 티어 인프라입니다.

| PC Tier | Network Zone | Hostname | IP Address | Role | 비고 |
|:---:|:---:|---|---|---|---|
| **PC1** | **Security** | `SECURE` | `172.16.6.61` (외부)<br>`10.2.1.1` (내부) | Gateway / Firewall | 포트포워딩 |
| | | `WAF` | `10.2.1.2` | Web Application Firewall | 웹 방화벽 (ModSecurity) |
| | | `DNS` | `10.2.1.3` | DNS Server | 내부 DNS (Bind9) |
| **PC2** | **K8s Master** | `K8S-ControlPlane1` | `10.2.2.2` | K8s Primary Master | HA 리더 |
| | | `K8S-ControlPlane2` | `10.2.2.3` | K8s Secondary Master | HA 멤버 |
| | | `K8S-ControlPlane3` | `10.2.2.4` | K8s Secondary Master | HA 멤버 |
| **PC3** | **K8s Workers** | `K8S-WorkerNode1` | `10.2.2.5` | Worker Node | 워커 그룹 A |
| | | `K8S-WorkerNode2` | `10.2.2.6` | Worker Node | 워커 그룹 A |
| | | `K8S-WorkerNode3` | `10.2.2.7` | Worker Node | 워커 그룹 A |
| **PC4** | **Database** | `DB-Proxy1` | `10.2.2.20` | HAProxy + Keepalived | DB 로드밸런서 (VIP 10.2.2.254) |
| | | `DB-Proxy2` | `10.2.2.21` | HAProxy + Keepalived | DB 로드밸런서 |
| | | `DB-Active` | `10.2.3.2` | PostgreSQL Master | Patroni Cluster |
| | | `DB-Standby` | `10.2.3.3` | PostgreSQL Replica | Patroni Cluster |
| | | `DB-Backup` | `10.2.3.4` | Backup Server | pgBackRest |
| | | `etcd_1` | `10.2.3.20` | Etcd Cluster | DB Leader Election |
| | | `etcd_2` | `10.2.3.21` | Etcd Cluster | DB Leader Election |
| | | `etcd_3` | `10.2.3.22` | Etcd Cluster | DB Leader Election |
| | | `Storage` | `10.2.2.30` | NFS Server | 공유 스토리지 |
| **PC5** | **Ops (CI/CD)** | `CI-OPS` | `10.2.2.40` | Jenkins + Gitea + Harbor | CI/CD & Registry |
| | **Monitoring** | `Monitoring` | `10.2.2.50` | Prometheus + Grafana | 모니터링 Master |
| | | `Monitoring_Backup` | `10.2.2.51` | Prometheus + Grafana | 모니터링 Standby |
| **PC6** | **K8s Workers** | `K8S-WorkerNode4` | `10.2.2.8` | Worker Node | 워커 그룹 B |
| | | `K8S-WorkerNode5` | `10.2.2.9` | Worker Node | 워커 그룹 B |
| | | `K8S-WorkerNode6` | `10.2.2.10` | Worker Node | 워커 그룹 B |

### 🔐 네트워크 아키텍처
- **보안 계층 (Security Tier)**: 외부와 내부를 연결하는 관문 (PC1)
- **쿠버네티스 클러스터 (K8s Tier)**: 실제 애플리케이션이 구동되는 영역 (PC2, PC3, PC6)
- **데이터베이스 계층 (DB Tier)**: 영구 데이터 저장소 (PC4 - ProxyJump 필수)
- **운영 계층 (Ops Tier)**: 관리 및 모니터링 시스템 (PC5)

---

## 🚀 2. 시작하기 (Getting Started)

### 🔑 1) SSH 키 배포 (필수)
모든 서버에 SSH 접근 권한을 배포합니다. (DB 서버 포함)

```bash
cd Script
./allserver_distribute_sshkeys.sh
```

### 🛠️ 2) 전체 프로비저닝 (Full Deployment)
명령어 하나로 전체 인프라를 구축합니다:

```bash
# 전체 실행 (site.yml)
ansible-playbook -i inventory.ini site.yml
```

### 🎯 3) 개별 플레이북 실행
특정 단계만 실행하려면 태그 또는 플레이북을 직접 실행하세요:

```bash
# 네트워크 초기 설정
ansible-playbook -i inventory.ini playbooks/00_network_provisioning.yml

# 보안 계층 (WAF, DNS, GW)
ansible-playbook -i inventory.ini playbooks/08_deploy_security.yml

# DB 계층 (PostgreSQL, Proxy, Etcd)
ansible-playbook -i inventory.ini playbooks/04_deploy_db.yml

# K8s 클러스터
ansible-playbook -i inventory.ini playbooks/02_k8s_install.yml
```

---

## 📜 3. 플레이북 구조 (Playbook Structure)

| 단계 | Playbook | 설명 | 대상 |
|---|---|---|---|
| **Step 0** | `00_network_provisioning.yml` | 네트워크/SSH 기본 설정 | All |
| **Step 1** | `01_common_setup.yml` | OS 기본 설정(패키지기, 방화벽) | All |
| **Step 1.5** | `08_deploy_security.yml` | **[보안]** Gateway, WAF, DNS 구축 | PC1 |
| **Step 2** | `04_deploy_db.yml` | **[DB]** PostgreSQL HA + ProxySQL 구축 | PC4 |
| **Step 3** | `02_k8s_install.yml` | **[K8s]** Master/Worker 노드 구축 | PC2,3,6 |
| **Step 4** | `03_deploy_monitoring.yml` | **[Ops]** Monitoring Stack 구축 | PC5 |
| **Step 5** | `05_deploy_cicd.yml` | **[Ops]** Jenkins + Gitea 구축 | PC5 |
| **Step 6** | `06_deploy_registry.yml` | **[Ops]** Harbor Registry 구축 | PC5 |
| **Step 7** | `07_deploy_argocd.yml` | **[CD]** ArgoCD 구축 | K8s |
| **Step 7.5** | `07_deploy_argocd_apps.yml` | **[App]** 마이크로서비스 자동 등록 | K8s |

---

## 🧩 4. Role 구조 (Ansible Roles)

모든 기능은 모듈화된 **Role**로 관리됩니다.

### 🛡️ Security Roles
- **`secure`**: Gateway 방화벽, 포트포워딩, NAT 설정
- **`waf`**: ModSecurity 웹 방화벽 설정
- **`dns`**: Bind9 내부 DNS 서버 설정

### 🐳 Kubernetes Roles
- **`k8s_base`**: 컨테이너 런타임(containerd) 및 공통 설정
- **`k8s_master`**: Control Plane 초기화 (kubeadm init/join)
- **`k8s_worker`**: Worker 노드 조인
- **`keepalived_haproxy`**: API Server 로드밸런싱 (VIP: 10.2.2.100)

### 🐘 Database Roles
- **`db`**: PostgreSQL, Patroni, Etcd 설정
- **`proxy`**: HAProxy + Keepalived (DB VIP 제공)
- **`backup`**: pgBackRest 백업 설정

### ⚙️ Ops/DevOps Roles
- **`monitoring`**: Prometheus, Grafana, Alertmanager
- **`jenkins`**: Jenkins CI 서버
- **`gitea`**: Gitea Git 서버
- **`harbor`**: Harbor Container Registry
- **`common`**: 전역 공통 설정

---

## 🖥️ 5. 사용자 환경 (UX)

모든 서버에 개발 편의를 위한 환경이 자동 구성됩니다.

- **Shell Prompt**: Tier별 색상 구분 (PC1 Red, PC2 Green, ...)
- **Desktop**: Antigravity 바로가기, Chrome, VS Code 자동 설치
- **Hostnames**: `PCx-Role` 형식으로 자동 표준화

---

## 🔍 6. 주요 접속 정보 (Access Info)

### 🌐 외부 접속 (via SECURE Gateway 172.16.6.61)
- **Grafana**: `http://172.16.6.61:3000`
- **Prometheus**: `http://172.16.6.61:9090`
- **Jenkins**: `http://172.16.6.61:8080`
- **Gitea**: `http://172.16.6.61:3001`
- **Harbor**: `http://172.16.6.61:5000`
- **ArgoCD**: `https://172.16.6.61:30xxx` (NodePort)
- **Web App**: `http://172.16.6.61:32506` (NodePort)

### 🔐 내부 접속 계정
- **OS**: `root` / (SSH Key)
- **DB**: `postgres` / (Vault 관리)
- **Tools**: `admin` / `admin123` (기본값)

---

**📅 Last Updated**: 2026-01-14
**👤 Maintainer**: Antigravity Team