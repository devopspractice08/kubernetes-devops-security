pipeline {
    agent any

    environment {
        IMAGE_NAME = "shaikh7/numeric-app"
        DOCKER_BUILDKIT = "0" // Disable BuildKit to avoid missing buildx issues
    }

    stages {

        stage('Pre-Build Cleanup') {
            steps {
                script {
                    // Clean old workspace files that can cause Docker context errors
                    sh '''
                        echo "Cleaning old trivy folder, target, and Docker cache..."
                        rm -rf trivy
                        rm -rf target
                        docker builder prune -af || true
                    '''
                    // Ensure correct .dockerignore exists
                    sh '''
                        cat > .dockerignore <<EOL
trivy
.git
.gitignore
.vscode
.idea
*.log
*.tmp
*.md
EOL
                    '''
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
                        sh '''
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
                        sh "chmod +x trivy-docker-image-scan.sh && bash trivy-docker-image-scan.sh"
                    },
                    "OPA Conftest": {
                        sh '''
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
                    sh '''
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker build --build-arg JAR_FILE=target/*.jar -t ${IMAGE_NAME}:${GIT_COMMIT} .
                        docker push ${IMAGE_NAME}:${GIT_COMMIT}
                    '''
                }
            }
        }

        stage('Kubernetes Deployment - Dev') {
            steps {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh '''
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
