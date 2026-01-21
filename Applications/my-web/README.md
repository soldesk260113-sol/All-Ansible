# myapp - Sample Application

## 📋 개요

Jenkins + Harbor CI/CD 파이프라인 데모용 샘플 Node.js 애플리케이션

## 🚀 빠른 시작

### 로컬 개발

```bash
# 의존성 설치
npm install

# 개발 서버 실행
npm run dev

# 테스트
npm test

# 프로덕션 빌드
npm run build
```

### Docker 빌드 및 실행

```bash
# 이미지 빌드
docker build -t myapp:1.0 .

# 컨테이너 실행
docker run -d -p 3000:3000 --name myapp myapp:1.0

# 확인
curl http://localhost:3000/health
```

## 🔄 CI/CD 워크플로우

### Jenkins Pipeline

1. **Checkout** - Gitea에서 소스 코드 가져오기
2. **Build & Test** - 애플리케이션 빌드 및 테스트
3. **Docker Build** - Docker 이미지 빌드
4. **Image Scan** - Trivy로 보안 스캔
5. **Push to Harbor** - Harbor Registry에 업로드

### Harbor에서 확인

```
URL: http://10.2.2.40:5000
Login: admin / Admin123
Projects → library → integrated-dashboard
```

### 다른 서버에서 사용

```bash
# Docker 설정 (최초 1회)
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["10.2.2.40:5000"]
}
EOF
systemctl restart docker

# Harbor 로그인
docker login 10.2.2.40:5000 -u admin -p Admin123

# 이미지 Pull
docker pull 10.2.2.40:5000/library/integrated-dashboard:latest

# 실행
docker run -d -p 8080:3000 --name my-web \
  --restart=always \
  10.2.2.40:5000/library/integrated-dashboard:latest

# 확인
curl http://localhost:8080/health
```

## ☸️ Helm & ArgoCD (GitOps)

이 프로젝트는 Helm Chart로 패키징되어 ArgoCD를 통해 배포됩니다.

### Helm Chart 구조

```
helm/
├── Chart.yaml       # 차트 메타데이터
├── values.yaml      # 기본 설정 (Image, Port 등)
└── templates/       # Kubernetes 리소스 템플릿
```

### 배포 설정 (`values.yaml`)

```yaml
image:
  repository: 10.2.2.40:5000/library/integrated-dashboard
  tag: "latest"
service:
  type: NodePort
  targetPort: 3000
```

### ArgoCD 동기화

1. ArgoCD 접속: https://172.16.6.61:30443 (또는 NodePort)
2. `my-web` 애플리케이션 선택
3. **Sync** 버튼 클릭하여 최신 상태 반영

### 접속 방법 (Ingress)

Ingress가 생성되면 다음 호스트로 접속할 수 있습니다.
(Host 파일 또는 DNS에 `10.2.2.101`이 등록되어 있어야 합니다.)

- **URL**: `http://my-web.antigravity.local`
- **VIP**: `10.2.2.101`

```bash
# 테스트
curl -H "Host: my-web.antigravity.local" http://10.2.2.101
```

## 📁 프로젝트 구조

```
myapp/
├── src/
│   └── index.js          # 메인 애플리케이션
├── tests/
│   └── app.test.js       # 테스트
├── helm/                 # Helm Chart (GitOps)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── k8s_manifests/        # Kubernetes 매니페스트 (레거시/참고용)
├── Dockerfile            # Docker 이미지 빌드
├── Jenkinsfile           # Jenkins 파이프라인
├── package.json          # Node.js 의존성
└── README.md
```

## 🔧 환경 변수

- `NODE_ENV`: 실행 환경 (production/development)
- `PORT`: 서버 포트 (기본: 3000)
- `APP_VERSION`: 애플리케이션 버전

## 🛠️ API 엔드포인트

- `GET /` - 홈페이지
- `GET /health` - Health check (Liveness)
- `GET /ready` - Readiness check
- `GET /api/info` - 애플리케이션 정보

## 📦 Harbor 이미지 태그

- `latest` - CD 파이프라인에 의해 빌드된 최신 이미지
- `<BUILD_NUMBER>` - Jenkins 빌드 번호

## 🔗 관련 링크

- **Jenkins**: http://10.2.2.40:8080
- **Gitea**: http://10.2.2.40:3001
- **Harbor**: http://10.2.2.40:5000
