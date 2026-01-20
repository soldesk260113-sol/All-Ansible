pipeline {
    agent any

    parameters {
        choice(name: 'PLAYBOOK', choices: ['08_deploy_security.yml'], description: 'Select the security playbook to run')
        string(name: 'LIMIT', defaultValue: 'all', description: 'Target hosts limit (e.g. PC1, WAF). Default: all')
        booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'Run in check mode (dry-run)?')
    }

    environment {
        ANSIBLE_FORCE_COLOR = 'true'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Pre-flight Check') {
            steps {
                script {
                   echo '🔍 Checking connectivity...'
                   sh 'ansible all -i inventory.ini -m ping -l "${LIMIT}"'
                }
            }
        }

        stage('Dry Run (Simulation)') {
            when {
                expression { return params.DRY_RUN == true }
            }
            steps {
                script {
                    echo "📦 Ansible 필수 모듈 설치 중..."
                    sh "ansible-galaxy collection install -r requirements.yml"
                    
                    echo "🔍 변경사항을 시뮬레이션 합니다 (Dry Run)..."
                    sh "ansible-playbook -i inventory.ini ${params.PLAYBOOK} -l \"${params.LIMIT}\" --check"
                }
            }
        }

        stage('Human Approval') {
            when {
                expression { return params.DRY_RUN == false }
            }
            steps {
                script {
                    input message: "'${params.PLAYBOOK}'를 실제로 배포하시겠습니까?", ok: "🚀 배포 승인 (Deploy)"
                }
            }
        }

        stage('Deploy (Apply)') {
            when {
                expression { return params.DRY_RUN == false }
            }
            steps {
                script {
                    echo "🚀 실제 배포를 시작합니다..."
                    sh "ansible-playbook -i inventory.ini ${params.PLAYBOOK} -l \"${params.LIMIT}\""
                }
            }
        }
    }
}
