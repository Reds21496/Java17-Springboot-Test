pipeline {
  agent { label 'java17' }

  options { buildDiscarder(logRotator(numToKeepStr: '15')) }

  environment {
    IMAGE_NAME = "mrojas444/java17-springboot-test"
    REGISTRY   = "docker.io"
    CRED_ID    = "dockerhub-mrojas444"
    REPO_URL   = "https://github.com/Reds21496/Java17-Springboot-Test.git"
    BRANCH     = "main"
    TAG        = ""   // we'll fill this after checkout
  }

  stages {
    stage('Checkout') {
      steps {
        container('tools') {
          echo "📦 Cloning ${REPO_URL} (branch: ${BRANCH})..."
          git url: "${REPO_URL}", branch: "${BRANCH}"
    
          // Make Git trust this shared workspace (multi-container/UID)
          sh 'git config --global --add safe.directory "$WORKSPACE" || true'
    
          // Compute and persist the tag once, in the same container that did the clone
          sh '''
            set -e
            cd "$WORKSPACE"
            git rev-parse --short=8 HEAD > .gitsha
            [ -s .gitsha ] || echo "${BUILD_NUMBER}" > .gitsha
            echo "SHA=$(cat .gitsha)"
          '''
    
          script {
            env.TAG = readFile('.gitsha').trim()
            echo "🧾 Using image tag: ${env.TAG}"
          }
        }
      }
    }
    stage('Verify Maven Container') {
      steps {
        container('maven') {
          sh '''
            set -eux
            java -version
            mvn -v
          '''
        }
      }
    }

    stage('Verify Tools Container') {
      steps {
        container('tools') {
          sh '''
            set -eux
            docker --version
            kubectl version --client
            trivy --version
            aws --version
          '''
        }
      }
    }

    stage('Build & Test (Maven)') {
      steps {
        container('maven') {
          sh '''
            set -eux
            if [ -x ./mvnw ]; then ./mvnw clean package -DskipTests=false
            else mvn clean package -DskipTests=false
            fi
          '''
        }
      }
      post {
        always {
          junit(testResults: '**/target/surefire-reports/*.xml, **/target/failsafe-reports/*.xml',
                allowEmptyResults: true)
        }
      }
    }

    stage('Docker Build & Push') {
      steps {
        container('tools') {
          withCredentials([usernamePassword(credentialsId: CRED_ID, usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh '''
              set -eux
              docker login -u "${DH_USER}" -p "${DH_PASS}"
              docker build -t ${IMAGE_NAME}:${TAG} -t ${IMAGE_NAME}:latest .
              docker push ${IMAGE_NAME}:${TAG}
              docker push ${IMAGE_NAME}:latest
              echo "✅ Pushed: ${IMAGE_NAME}:${TAG} and :latest"
            '''
          }
        }
      }
    }
  }

  post {
    success { echo "✅ Build successful — image pushed to Docker Hub!" }
    failure { echo "❌ Build failed." }
  }
}
