pipeline {
    agent any

    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }

    environment {
        AWS_REGION       = 'us-east-1'
        ECR_REPO         = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sample-app"
        IMAGE_TAG        = "${env.GIT_COMMIT.take(7)}-${env.BUILD_NUMBER}"
        SONARQUBE_ENV    = 'SonarQubeServer'
        EKS_CLUSTER      = 'app-eks-cluster'
        K8S_NAMESPACE    = "${params.ENVIRONMENT}"
        HELM_RELEASE     = 'app-release'
        HELM_CHART_PATH  = 'helm/app-chart'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target deployment environment')
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Unit Test') {
            steps {
                dir('app') {
                    sh 'mvn -B clean verify'
                }
            }
            post {
                always {
                    junit 'app/target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('app') {
                    withSonarQubeEnv("${SONARQUBE_ENV}") {
                        sh 'mvn -B sonar:sonar -Dsonar.projectKey=sample-app'
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REPO}

                        docker build -t ${ECR_REPO}:${IMAGE_TAG} -t ${ECR_REPO}:latest .
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest
                    """
                }
            }
        }

        stage('Deploy via Helm') {
            steps {
                script {
                    sh """
                        aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}

                        helm upgrade --install ${HELM_RELEASE} ${HELM_CHART_PATH} \
                            --namespace ${K8S_NAMESPACE} --create-namespace \
                            --set image.repository=${ECR_REPO} \
                            --set image.tag=${IMAGE_TAG} \
                            -f ${HELM_CHART_PATH}/values-${K8S_NAMESPACE}.yaml \
                            --atomic --timeout 5m
                    """
                }
            }
        }

        stage('Verify Rollout') {
            steps {
                sh "kubectl rollout status deployment/sample-app -n ${K8S_NAMESPACE} --timeout=120s"
            }
        }
    }

    post {
        failure {
            echo 'Pipeline failed — capturing diagnostics.'
            sh """
                kubectl get pods -n ${K8S_NAMESPACE} || true
                kubectl describe deployment sample-app -n ${K8S_NAMESPACE} || true
            """
        }
        success {
            echo "Deployed image ${ECR_REPO}:${IMAGE_TAG} to ${K8S_NAMESPACE}"
        }
    }
}
