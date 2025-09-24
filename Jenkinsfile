pipeline {
  agent any

  tools {
    jdk 'JDK17'    // ensure JDK17 is configured in Jenkins Global Tool Config
    maven 'Maven3' // optional
  }

  environment {
    DOCKERHUB_USER      = 'saitejakarimeraka3577'
    IMAGE_NAME          = "${DOCKERHUB_USER}/demo-app"
    K8S_NAMESPACE       = 'default'
    K8S_DEPLOYMENT      = 'demo-deployment'

    // Credentials (from your screenshot)
    DOCKER_CREDS_ID     = 'DOCKERHUBCRED'   // Docker Hub username/password
    AWS_CRED_ID         = 'aws_credentials' // AWS credentials (used to update kubeconfig for EKS)

    // Required for EKS path
    EKS_CLUSTER_NAME    = 'springbootapplication-cluster' 
    AWS_REGION          = 'ap-southeast-2'            
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
      environment {
        JAVA_HOME = "${tool 'JDK17'}"
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
      }
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
        withCredentials([usernamePassword(credentialsId: "${env.DOCKER_CREDS_ID}",
                                          usernameVariable: 'DOCKERHUB_USERNAME',
                                          passwordVariable: 'DOCKERHUB_PASSWORD')]) {
          sh '''
            echo "Logging in to Docker Hub as ${DOCKERHUB_USERNAME}"
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
        echo "Using AWS credentials id: ${env.AWS_CRED_ID} to update kubeconfig and deploy to EKS"
        // Uses the Amazon Web Services Credentials plugin binding
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${env.AWS_CRED_ID}"]]) {
          sh '''
            set -e
            # Verify required CLIs are present
            aws --version || { echo "aws CLI not found on agent"; exit 1; }
            kubectl version --client=true || { echo "kubectl not found on agent"; exit 1; }
            docker --version || echo "docker not found (if using docker on agent, ensure it's installed)"

            # Create/update kubeconfig for EKS using bound AWS creds (AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY)
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}

            # sanity check
            kubectl get nodes -n ${K8S_NAMESPACE} --no-headers -o wide || true

            # deploy or update image
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
      echo "Deployment failed — attempting rollback using EKS/AWS credentials"
      withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${env.AWS_CRED_ID}"]]) {
        sh '''
          set -e || true
          aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} || true
          kubectl rollout undo deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} || true
          kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=180s || true
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
