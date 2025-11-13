pipeline {
    agent any

    environment {
        IMAGE_NAME = "shaikh7/numeric-app"
        DOCKER_BUILDKIT = "0"
    }

    stages {

        stage('Pre-Build Cleanup') {
            steps {
                script {
                    echo "🧹 Cleaning old workspace files..."
                    sh '''#!/bin/bash
                        # Clean everything safely
                        rm -rf trivy || true
                        rm -rf target || true
                        rm -rf .dockerignore || true

                        # Fix permissions (avoid Jenkins stat errors)
                        sudo chown -R jenkins:jenkins .
                        sudo chmod -R 755 .

                        # Prune any stale Docker build cache
                        docker builder prune -af || true
                    '''

                    echo "📄 Creating fresh .dockerignore file"
                    sh '''#!/bin/bash
                        cat > .dockerignore <<EOL
trivy
.git
.gitignore
.vscode
.idea
*.log
*.tmp
*.md
target/
EOL
                    '''

                    echo "✅ Workspace cleanup complete"
                }
            }
        }

        stage('Build Artifact') {
            steps {
                sh "mvn clean package -DskipTests=true"
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Unit Tests') {
            steps {
                sh "mvn test"
            }
        }

        stage('Mutation Tests - PIT') {
            steps {
                sh "mvn org.pitest:pitest-maven:mutationCoverage"
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
                            sh "mvn dependency-check:check"
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
                        echo "🐳 Starting Docker Build..."
                        retry(2) {
                            sh '''#!/bin/bash
                                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                                docker build --no-cache --build-arg JAR_FILE=target/*.jar -t ${IMAGE_NAME}:${GIT_COMMIT} .
                                docker push ${IMAGE_NAME}:${GIT_COMMIT}
                            '''
                        }
                        echo "📤 Docker image pushed successfully!"
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
    }
}
