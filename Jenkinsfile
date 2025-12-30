pipeline {
    agent any

    stages {
        stage('Cleanup Workspace') {
            steps {
                // This ensures every build starts with a clean slate and no permission ghosts
                sh 'sudo chown -R jenkins:jenkins $WORKSPACE'
                sh 'rm -rf trivy target' 
            }
        }

        stage('Build Artifact - Maven') {
            steps {
                sh 'mvn clean package -DskipTests=true'
            }
        }

        stage('Unit Tests & PIT') {
            // Combining these to save time and ensure reports stay put
            steps {
                sh 'mvn test'
                sh 'mvn org.pitest:pitest-maven:mutationCoverage'
            }
        }

        stage('SonarQube - SAST') {
            steps {
                // NO CLEAN here. Just analysis.
                sh '''
                    mvn sonar:sonar \
                    -Dsonar.projectKey=numeric-application \
                    -Dsonar.host.url=http://3.108.200.102:9000 \
                    -Dsonar.login=sqp_f60bb81b6ffeeb7ffd83d5a782c18cdd6efd784b
                '''
            }
        }

        stage('Vulnerability Scan') {
            steps {
                parallel(
                    'Dependency Scan': {
                        sh 'mvn dependency-check:check -DskipTests=true || true'
                    },
                    'Trivy Scan': {
                        sh '''
                            chmod +x trivy-docker-image-scan.sh
                            ./trivy-docker-image-scan.sh shaikh7/numeric-app:${GIT_COMMIT} || true
                        '''
                    }
                )
            }
        }

       stage('Docker Build & Push') {
            steps {
                withDockerRegistry([credentialsId: 'docker-hub', url: '']) {
                    sh '''
                        # 1. Clear any old app.jar in the root
                        rm -f ./app.jar
                        
                        # 2. Copy the jar from target to the current root directory
                        cp target/*.jar ./app.jar
                        
                        # 3. Build the image (Docker will now look for app.jar in the root)
                        docker build -t shaikh7/numeric-app:${GIT_COMMIT} -f - . <<EOF
FROM eclipse-temurin:8-jre-jammy
WORKDIR /app
COPY app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
EOF
                        
                        # 4. Push the image
                        docker push shaikh7/numeric-app:${GIT_COMMIT}
                        
                        # 5. Cleanup the temp jar
                        rm -f ./app.jar
                    '''
                }
            }
        }
        stage('Kubernetes Deployment') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        sed -i "s#replace#shaikh7/numeric-app:${GIT_COMMIT}#g" k8s_deployment_service.yaml
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
            // Clean up permissions at the end so the NEXT build doesn't fail
            sh 'sudo chown -R jenkins:jenkins $WORKSPACE'
        }
    }
}
