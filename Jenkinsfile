pipeline {
    agent any

    environment {
        IMAGE_NAME = "shaikh7/numeric-app"
        DOCKER_BUILDKIT = "1"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build JAR') {
            steps {
                echo "🏗️ Building Java Application..."
                sh 'mvn clean package -DskipTests=true'
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

                        echo "✅ Checking for .dockerignore..."
                        sh '''
                            if [ ! -f .dockerignore ]; then
                                echo "⚠️ .dockerignore missing, creating..."
                                echo "trivy" > .dockerignore
                            fi
                        '''

                        echo "📦 Preparing JAR file..."
                        sh '''
                            if [ ! -f target/numeric-0.0.1.jar ]; then
                                echo "❌ JAR file not found in target/. Check your Maven build."
                                exit 1
                            fi
                        '''

                        echo "🚀 Building Docker image..."
                        sh '''
                            docker build --no-cache \
                            --build-arg JAR_FILE=target/numeric-0.0.1.jar \
                            -t ${IMAGE_NAME}:${GIT_COMMIT} .
                        '''

                        echo "📤 Pushing Docker image..."
                        sh 'docker push ${IMAGE_NAME}:${GIT_COMMIT}'
                    }
                }
            }
        }

        stage('Post Build Cleanup') {
            steps {
                echo "🧹 Cleaning up old Docker images..."
                sh '''
                    docker rmi ${IMAGE_NAME}:${GIT_COMMIT} || true
                    docker system prune -f || true
                '''
            }
        }
    }
}
