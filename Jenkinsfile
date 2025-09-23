pipeline {
  agent any

  environment {
    DOCKERHUB_USER = 'saitejakarimeraka3577'
    IMAGE_NAME = "${DOCKERHUB_USER}/demo-app"
    K8S_NAMESPACE = 'default'
    K8S_DEPLOYMENT = 'demo-deployment'
  }

  options {
    buildDiscarder(logRotator(daysToKeepStr: '7', numToKeepStr: '20'))
    timestamps()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          GIT_SHA = sh(returnStdout: true, script: "git rev-parse --short=8 HEAD || echo ${env.BUILD_NUMBER}").trim()
          env.IMAGE_TAG = "${GIT_SHA}"
          echo "Using image tag: ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build (Maven)') {
      steps {
        sh 'mvn -B -DskipTests clean package'
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          def buildCmd = sh(returnStatus: true, script: 'command -v docker-buildx >/dev/null 2>&1') == 0 ?
                         "docker buildx build --platform linux/amd64 -t ${IMAGE_NAME}:${IMAGE_TAG} --load ." :
                         "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
          sh "${buildCmd}"
          sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                          usernameVariable: 'DOCKERHUB_USERNAME',
                                          passwordVariable: 'DOCKERHUB_PASSWORD')]) {
          sh '''
            echo "Logging in to Docker Hub"
            echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USERNAME --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
            docker logout
          '''
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            export KUBECONFIG="$KUBECONFIG_FILE"
            kubectl version --client=true
            kubectl get nodes --no-headers -o wide || true

            # Update deployment image if exists
            if kubectl get deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} >/dev/null 2>&1; then
              kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_DEPLOYMENT}=${IMAGE_NAME}:${IMAGE_TAG} -n ${K8S_NAMESPACE}
            else
              kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
              kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}
            fi

            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=180s
          '''
        }
      }
    }
  }

  post {
    failure {
      echo "Deployment failed — rolling back"
      withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
        sh '''
          export KUBECONFIG="$KUBECONFIG_FILE"
          kubectl rollout undo deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
          kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=120s || true
        '''
      }
    }
    success {
      echo "✅ Build & deploy succeeded: ${IMAGE_NAME}:${IMAGE_TAG}"
    }
    cleanup {
      sh 'rm -f k8s/deployment-gen.yaml || true'
    }
  }
}
