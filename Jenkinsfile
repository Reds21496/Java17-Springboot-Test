pipeline {
  agent { label 'java17' }

  options { buildDiscarder(logRotator(numToKeepStr: '15')) }

  environment {
    IMAGE_NAME = "mrojas444/java17-springboot-test"
    REGISTRY   = "docker.io"
    CRED_ID    = "dockerhub-mrojas444"
    REPO_URL   = "https://github.com/Reds21496/Java17-Springboot-Test.git"
    BRANCH     = "main"
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
        container('kaniko') {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-mrojas444', usernameVariable: 'DHU', passwordVariable: 'DHP')]) {
            sh '''
              set -euo pipefail
    
              echo "WORKSPACE=${WORKSPACE}"
              ls -la "${WORKSPACE}" || true
              ls -la "${WORKSPACE}/target" || true
    
              # ---- Auth for Docker Hub (config.json) ----
              mkdir -p /kaniko/.docker
              AUTH=$(printf "%s:%s" "$DHU" "$DHP" | base64 -w0 2>/dev/null || printf "%s:%s" "$DHU" "$DHP" | base64 | tr -d '\\n')
cat > /kaniko/.docker/config.json <<'EOF'
{
     "auths": {
    "https://index.docker.io/v1/": { "auth": "__AUTH__" }
     }
}
EOF
              sed -i "s#__AUTH__#${AUTH}#g" /kaniko/.docker/config.json
    
              # ---- Resolve image + tag ----
              IMAGE="docker.io/${IMAGE_NAME}"   # e.g., docker.io/mrojas444/java17-springboot-test
              if [ -f "${WORKSPACE}/.gitsha" ] && [ -s "${WORKSPACE}/.gitsha" ]; then
                TAG="$(cat "${WORKSPACE}/.gitsha")-${BUILD_NUMBER}"
              else
                TAG="$(git -C "${WORKSPACE}" rev-parse --short=8 HEAD 2>/dev/null || echo "${BUILD_NUMBER}")"
              fi
              echo "Will push: ${IMAGE}:${TAG}"
    
              # ---- Verify the JAR exists (fail early if not) ----
              JAR_COUNT=$(ls -1 "${WORKSPACE}"/target/*.jar 2>/dev/null | wc -l || true)
              if [ "${JAR_COUNT}" -eq 0 ]; then
                echo "ERROR: No JAR found under ${WORKSPACE}/target. Did the Maven stage run?" >&2
                exit 1
              fi
              echo "Found JAR(s):"
              ls -1 "${WORKSPACE}"/target/*.jar
    
              # ---- Build & push with Kaniko (runtime-only Dockerfile) ----
              /kaniko/executor \
                -v=debug \
                --context "${WORKSPACE}" \
                --dockerfile "${WORKSPACE}/Dockerfile" \
                --destination "${IMAGE}:${TAG}" \
                --destination "${IMAGE}:latest" \
                --digest-file /tmp/digest.txt \
                --cache=true \
                --cache-repo "docker.io/${IMAGE_NAME}-cache" \
                --snapshot-mode=redo
    
              echo "Pushed digest: $(cat /tmp/digest.txt)"
    
              # ---- Verify tag on Docker Hub (public repos) ----
              USER="${IMAGE_NAME%%/*}"
              REPO="${IMAGE_NAME##*/}"
              echo "Checking ${USER}/${REPO}:${TAG} on Docker Hub…"
              curl -fsSL "https://registry.hub.docker.com/v2/repositories/${USER}/${REPO}/tags/${TAG}" >/dev/null \
                && echo "✅ Tag ${TAG} is visible on Docker Hub." \
                || echo "⚠️  Tag not visible via public API (private repo or eventual consistency)."
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
