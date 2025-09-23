pipeline {
    agent any

    environment {
        DOCKERHUB_REPO = 'YOUR_DOCKERHUB_USER/demo-app'    // change this
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        K8S_NAMESPACE = 'default'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build JAR') {
            steps {
                sh 'mvn -B -DskipTests clean package'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKERHUB_REPO}:${IMAGE_TAG} ."
                    sh "docker tag ${DOCKERHUB_REPO}:${IMAGE_TAG} ${DOCKERHUB_REPO}:latest"
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                usernameVariable: 'DOCKER_USER',
                                                passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                       echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                       docker push ${DOCKERHUB_REPO}:${IMAGE_TAG}
                       docker push ${DOCKERHUB_REPO}:latest
                       """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig',
                                      variable: 'KUBECONFIG_FILE')]) {
                    sh '''
                       export KUBECONFIG=$KUBECONFIG_FILE
                       sed "s|YOUR_DOCKERHUB_USER/demo-app:latest|${DOCKERHUB_REPO}:${IMAGE_TAG}|g" k8s/deployment.yaml > k8s/deployment-gen.yaml
                       kubectl apply -f k8s/deployment-gen.yaml -n ${K8S_NAMESPACE}
                       kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}
                       kubectl rollout status deployment/demo-deployment -n ${K8S_NAMESPACE} --timeout=180s
                       '''
                }
            }
        }
    }

    post {
        failure {
            echo "❌ Deployment failed, rolling back..."
            withCredentials([file(credentialsId: 'kubeconfig',
                                  variable: 'KUBECONFIG_FILE')]) {
                sh '''
                   export KUBECONFIG=$KUBECONFIG_FILE
                   kubectl rollout undo deployment/demo-deployment -n ${K8S_NAMESPACE}
                   '''
            }
        }
        success {
            echo "✅ Build, Push, and Deploy completed successfully!"
        }
    }
}
