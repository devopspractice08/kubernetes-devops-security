pipeline {
    agent any

    environment {
        IMAGE_NAME = "shaikh7/numeric-app"
        DOCKER_BUILDKIT = "0" // ✅ Disable BuildKit to avoid buildx error
    }

    stages {

        // -------------------------------------------------------------------
        stage('Pre-Build Cleanup') {
            steps {
                script {
                    echo "🧹 Cleaning old workspace files..."

                    // Create .dockerignore (exclude unnecessary files)
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

                    // Clean and fix permissions
                    sh '''#!/bin/bash
                        rm -rf trivy || true
                        rm -rf target || true
                        sudo chown -R jenkins:jenkins . || true
                        sudo chmod -R 755 . || true
                        docker builder prune -af || true
                    '''
                    echo "✅ Workspace cleanup complete"
                }
            }
        }

        // -------------------------------------------------------------------
        stage('Build Artifact') {
            steps {
                echo "🏗️ Building Maven Artifact..."
                sh "mvn clean package -DskipTests=true"
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        // -------------------------------------------------------------------
        stage('Unit Tests') {
            steps {
                echo "🧪 Running Unit Tests..."
                sh "mvn test"
            }
        }

        // -------------------------------------------------------------------
        stage('Mutation Tests - PIT') {
            steps {
                echo "🧬 Running Mutation Tests..."
                sh "mvn org.pitest:pitest-maven:mutationCoverage"
            }
        }

        // -------------------------------------------------------------------
        stage('SonarQube - SAST') {
            steps {
                echo "🔍 Running SonarQube Scan..."
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

        // -------------------------------------------------------------------
        stage('Vulnerability Scans') {
            steps {
                parallel(
                    "Dependency Check (Maven)": {
                        echo "🛡️ Dependency Check..."
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh "mvn org.owasp:dependency-check-maven:check"
                        }
                    },
                    "Trivy File Scan": {
                        echo "🐋 Trivy Security Scan..."
                        sh '''#!/bin/bash
                            if ! command -v trivy &> /dev/null; then
                                echo "Installing Trivy..."
                                curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
                            fi
                            trivy fs --exit-code 0 --severity HIGH,CRITICAL .
                        '''
                    },
                    "OPA Conftest Policy": {
                        echo "🧾 OPA Conftest Policy Scan..."
                        sh '''#!/bin/bash
                            docker run --rm -v $(pwd):/project openpolicyagent/conftest:v0.33.0 \
                            test --policy opa-docker-security.rego Dockerfile
                        '''
                    }
                )
            }
        }

        // -------------------------------------------------------------------
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

                echo "📦 Preparing JAR for Docker build..."
                sh '''
                    # Ensure JAR exists
                    mvn clean package -DskipTests=true

                    # Copy JAR to workspace root so Docker can access it easily
                    JAR_FILE=$(ls target/*.jar | head -n 1)
                    cp $JAR_FILE app.jar

                    echo "✅ Copied JAR to workspace root:"
                    ls -l app.jar
                '''

                echo "🏗️ Building Docker image..."
                sh '''
                    docker build --no-cache \
                        --build-arg JAR_FILE=app.jar \
                        -t ${IMAGE_NAME}:${GIT_COMMIT} \
                        -t ${IMAGE_NAME}:latest .
                '''

                echo "📤 Pushing Docker image..."
                sh '''
                    docker push ${IMAGE_NAME}:${GIT_COMMIT}
                    docker push ${IMAGE_NAME}:latest
                '''

                echo "✅ Docker image built and pushed successfully!"
            }
        }
    }
}




        stage('Vulnerability Scan - Kubernetes') {
    steps {
        echo "🔒 Starting OPA (Open Policy Agent) scan for Kubernetes manifests..."
        sh '''#!/bin/bash
            echo "🧩 Running OPA (Open Policy Agent) scan..."
            docker run --rm -v $(pwd):/project openpolicyagent/conftest \
                test --policy opa-k8s-security.rego k8s_deployment_service.yaml
        '''
        echo "✅ OPA scan completed successfully!"
    }
}

        // -------------------------------------------------------------------
        stage('Kubernetes Deployment - Dev') {
            steps {
                echo "🚀 Deploying to Kubernetes (Dev)..."
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh '''#!/bin/bash
                        sed -i "s#replace#${IMAGE_NAME}:${GIT_COMMIT}#g" k8s_deployment_service.yaml
                        kubectl apply -f k8s_deployment_service.yaml
                    '''
                }
            }
        }
    }

    // -------------------------------------------------------------------
    post {
        always {
            echo "📦 Publishing reports..."
            junit 'target/surefire-reports/*.xml'
            jacoco execPattern: 'target/jacoco.exec'
            pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'

            script {
                try {
                    dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
                } catch (err) {
                    echo "⚠️ Dependency report missing: ${err}"
                }
            }
        }
    }
}
