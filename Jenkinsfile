pipeline {
    agent any

    environment {
        IMAGE_NAME = "shaikh7/numeric-app"
        DOCKER_BUILDKIT = "1"
    }

    stages {

        stage('Checkout Code') {
            steps {
                echo "🔁 Checking out code from SCM..."
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
                        credentialsId: 'docker-hub-cred',  // 🔹 Jenkins Docker Hub credentials ID
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    script {
                        echo "🐳 Logging into Docker Hub..."
                        sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'

                        echo "✅ Ensuring .dockerignore exists..."
                        sh '''
                            if [ ! -f .dockerignore ]; then
                                echo "⚠️ .dockerignore missing, creating..."
                                echo "trivy" > .dockerignore
                            fi
                        '''

                        echo "🔍 Checking JAR file..."
                        sh '''
                            if [ ! -f target/numeric-0.0.1.jar ]; then
                                echo "❌ ERROR: JAR file not found in target/."
                                echo "👉 Make sure Maven build creates target/numeric-0.0.1.jar"
                                exit 1
                            fi
                        '''

                        echo "🚀 Building Docker image..."
                        sh '''
                            docker build --no-cache \
                            --build-arg JAR_FILE=target/numeric-0.0.1.jar \
                            -t ${IMAGE_NAME}:${GIT_COMMIT} \
                            -t ${IMAGE_NAME}:latest .
                        '''

                        echo "📤 Pushing Docker image to Docker Hub..."
                        sh '''
                            docker push ${IMAGE_NAME}:${GIT_COMMIT}
                            docker push ${IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }

        stage('Post Build Cleanup') {
            steps {
                echo "🧹 Cleaning up Docker images and system..."
                sh '''
                    docker rmi ${IMAGE_NAME}:${GIT_COMMIT} || true
                    docker rmi ${IMAGE_NAME}:latest || true
                    docker system prune -f || true
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Build & Push Successful!"
        }
        failure {
            echo "❌ Build Failed. Check logs for details."
        }
    }
}
