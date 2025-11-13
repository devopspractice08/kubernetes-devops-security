pipeline {
    agent any

    environment {
        IMAGE_NAME = "shaikh7/numeric-app"
        DOCKER_BUILDKIT = "1" // enable modern Docker builder
    }

    stages {

        stage('Pre-Build Cleanup') {
            steps {
                script {
                    echo "🧹 Cleaning old workspace files..."

                    sh '''#!/bin/bash
                        # Remove broken folders and old files
                        sudo rm -rf trivy || true
                        sudo rm -rf target || true
                        sudo rm -rf .dockerignore || true

                        # Recreate .dockerignore fresh
                        cat > .dockerignore <<EOL
trivy
target/
.git
.gitignore
.vscode
.idea
*.log
*.tmp
*.md
EOL

                        # Reset permissions for Jenkins
                        sudo chown -R jenkins:jenkins .
                        sudo chmod -R 755 .

                        # Clean old Docker cache
                        docker builder prune -af || true
                    '''

                    echo "✅ Workspace cleanup complete"
                }
            }
        }

        stage('Build Artifact') {
            steps {
                echo "🏗️ Building Maven artifact..."
                sh 'mvn clean package -DskipTests=true'

                echo "🔍 Checking if JAR file exists..."
                sh '''#!/bin/bash
                    if [ ! -f target/numeric-0.0.1.jar ]; then
                        echo "❌ ERROR: target/numeric-0.0.1.jar not found!"
                        exit 1
                    fi
                '''
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Unit Tests') {
            steps {
                echo "🧪 Running unit tests..."
                sh 'mvn test'
            }
        }

        stage('Mutation Tests - PIT') {
            steps {
                sh 'mvn org.pitest:pitest-maven:mutationCoverage'
            }
        }

        stage('SonarQube - SAST') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh '''#!/bin/bash
                            mvn sonar:sonar \
                              -Dsonar.projectKey=numeric-application \
                              -Dsonar.host.url=http://65.1.83.73:9000 \
                              -Dsonar.login=$SONAR_TOKEN
                        '''
                    }
                }
            }
        }

        stage('Vulnerability Scan - Docker') {
            steps {
                parallel(
                    "Dependency Scan": {
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh 'mvn dependency-check:check'
                        }
                    },
                    "Trivy Scan": {
                        sh '''#!/bin/bash
                            chmod +x trivy-docker-image-scan.sh || true
                            bash trivy-docker-image-scan.sh || true
                        '''
                    },
                    "OPA Conftest": {
                        sh '''#!/bin/bash
                            docker run --rm -v $(pwd):/project openpolicyagent/conftest:v0.33.0 \
                            test --policy opa-docker-security.rego Dockerfile
                        '''
                    }
                )
            }
        }

        stage('Docker Build and Push') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub-cred',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    script {
                        echo "🐳 Logging into Docker Hub..."
                        sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'

                        echo "🏗️ Building Docker image..."
                        sh '''#!/bin/bash
                            docker build --no-cache \
                              --build-arg JAR_FILE=target/numeric-0.0.1.jar \
                              -t ${IMAGE_NAME}:${GIT_COMMIT} \
                              -t ${IMAGE_NAME}:latest .
                        '''

                        echo "📤 Pushing Docker image..."
                        sh '''
                            docker push ${IMAGE_NAME}:${GIT_COMMIT}
                            docker push ${IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }

        stage('Kubernetes Deployment - Dev') {
            steps {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh '''#!/bin/bash
                        sed -i "s#replace#${IMAGE_NAME}:${GIT_COMMIT}#g" k8s_deployment_service.yaml
                        kubectl apply -f k8s_deployment_service.yaml
                    '''
                }
            }
        }
    }

    post {
        always {
            junit 'target/surefire-reports/*.xml'
            jacoco execPattern: 'target/jacoco.exec'
            pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
            script {
                try {
                    dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
                } catch (err) {
                    echo "Dependency-Check report not found or failed: ${err}"
                }
            }
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed — check logs carefully!"
        }
    }
}
