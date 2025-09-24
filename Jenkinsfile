pipeline {
  agent any  

  tools {
    jdk 'JDK17'  
  }

  environment {
    DOCKERHUB_USER      = 'saitejakarimeraka3577'
    IMAGE_NAME          = "${DOCKERHUB_USER}/demo-app"
    K8S_NAMESPACE       = 'default'
    K8S_DEPLOYMENT      = 'demo-deployment'

    DOCKER_CREDS_ID     = 'DOCKERHUBCRED'
    AWS_CRED_ID         = 'aws_credentials'
    EKS_CLUSTER_NAME    = 'springbootapplication-cluster' 
    AWS_REGION          = 'ap-southeast-2'    
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

    stage('Build Docker Image') {
      steps {
        script {
          def hasBuildx = sh(returnStatus: true, script: 'docker buildx version >/dev/null 2>&1') == 0
          def buildCmd = hasBuildx ? "docker buildx build --platform linux/amd64 -t ${IMAGE_NAME}:${IMAGE_TAG} --load ." :
                                     "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
          sh "${buildCmd}"
          sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${env.DOCKER_CREDS_ID}",
                                          usernameVariable: 'DOCKERHUB_USERNAME',
                                          passwordVariable: 'DOCKERHUB_PASSWORD')]) {
          sh '''
            echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USERNAME --password-stdin
            docker push ${IMAGE_NAME}:${IMAGE_TAG}
            docker push ${IMAGE_NAME}:latest
            docker logout
          '''
        }
      }
    }

    stage('Deploy to EKS (AWS creds)') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${env.AWS_CRED_ID}"]]) {
          sh '''
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}

            if kubectl get deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} >/dev/null 2>&1; then
              kubectl set image deployment/${K8S_DEPLOYMENT} demo=${IMAGE_NAME}:${IMAGE_TAG} -n ${K8S_NAMESPACE}
            else
              kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
              kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}
            fi

            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=300s
          '''
        }
      }
    }
  }

  post {
    failure {
      echo "❌ Deployment failed — attempting rollback"
      withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${env.AWS_CRED_ID}"]]) {
        sh '''
          aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} || true
          kubectl rollout undo deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} || true
        '''
      }
    }
    success {
      echo "✅ Build & deploy succeeded: ${IMAGE_NAME}:${IMAGE_TAG}"
    }
  }
}
