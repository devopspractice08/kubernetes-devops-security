pipeline {
    agent any

    stages {
        stage('Build Artifact') {
            steps {
                sh "mvn clean package -DskipTests=true"
                archiveArtifacts 'target/*.jar'
            }
        }

        stage('Unit Tests') {
            steps {
                sh "mvn test"
            }
            post {
                always {
                    // Publish test results
                    junit 'target/surefire-reports/*.xml'
                    // Publish Jacoco code coverage
                    jacoco execPattern: 'target/jacoco.exec'
                }
            }
        }

        stage('Mutation Tests - PIT') {
       steps {
         sh "mvn org.pitest:pitest-maven:mutationCoverage"
       }
            post{
                always{
                    pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
                }
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
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh 'docker build -t shaikh7/numeric-app:${GIT_COMMIT} .'
                    sh 'docker push shaikh7/numeric-app:${GIT_COMMIT}'
                }
            }
        }

        stage('Kubernetes Deployment - Dev') {
            steps {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh "sed -i 's#replace#shaikh7/numeric-app:$GIT_COMMIT#g' k8s_deployment_service.yaml"
                    sh "kubectl apply -f k8s_deployment_service.yaml"
                }
            }
        }
    }
}
