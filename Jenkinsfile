pipeline {
    agent any

    environment {
        deploymentName = 'devsecops'
        containerName  = 'devsecops-container'
        serviceName    = 'devsecops-svc'
        imageName      = "shaikh7/numeric-app:${GIT_COMMIT}" // Updated to your Docker ID
        applicationURL = 'http://3.108.200.102:32523/'
        applicationURI = '/increment/99'
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
                // Ensures a clean slate and fixes permission ghosts from previous runs
                sh 'sudo chown -R jenkins:jenkins $WORKSPACE'
                sh 'rm -rf trivy target app.jar' 
            }
        }

        stage('Build Artifact - Maven') {
            steps {
                sh 'mvn clean package -DskipTests=true'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Unit Tests - JUnit and JaCoCo') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Mutation Tests - PIT') {
            steps {
                // We do NOT use 'mvn clean' here to keep test results for Sonar
                sh 'mvn org.pitest:pitest-maven:mutationCoverage'
            }
        }

        stage('SonarQube - SAST') {
            steps {
                // We remove 'withSonarQubeEnv' and pass the details directly to Maven
                sh """
                    mvn sonar:sonar \
                    -Dsonar.projectKey=numeric-application \
                    -Dsonar.host.url=http://3.108.200.102:9000 \
                    -Dsonar.login=sqp_f60bb81b6ffeeb7ffd83d5a782c18cdd6efd784b
                """
            }
        }
        stage('Security Scans (Parallel)') {
            steps {
                parallel(
                    'Dependency Scan': {
                        sh 'mvn dependency-check:check -DskipTests=true || true'
                    },
                    'Trivy Container Scan': {
                        sh '''
                            chmod +x trivy-docker-image-scan.sh
                            ./trivy-docker-image-scan.sh ${imageName} || true
                        '''
                    },
                    'OPA Docker Policy': {
                        sh 'docker run --rm -v $(pwd):/project -w /project openpolicyagent/conftest test --policy opa-docker-security.rego Dockerfile || true'
                    }
                )
            }
        }

        stage('Docker Build & Push') {
            steps {
                withDockerRegistry([credentialsId: 'docker-hub', url: '']) {
                    sh """
                        docker build -t ${imageName} .
                        docker push ${imageName}
                    """
                }
            }
        }

       stage('Vulnerability Scan') {
      steps {
        parallel(
          'OPA Scan': {
            sh '''
              docker run --rm -v $(pwd):/project \
                openpolicyagent/conftest test \
                --policy opa-k8s-security.rego \
                k8s_deployment_service.yaml
            '''
          },
          'Kubesec Scan': {
            sh 'bash kubesec-scan.sh'
          },
            "Trivy Scan": {
             sh "bash trivy-k8s-scan.sh"
           }
        )
      }
    }
  

        stage('K8S Deployment - DEV') {
            steps {
                parallel(
                    'Deployment': {
                        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                            // Using sed to inject the dynamic image name into the YAML
                            sh """
                                sed -i "s#replace#${imageName}#g" k8s_deployment_service.yaml
                                kubectl apply -f k8s_deployment_service.yaml
                            """
                        }
                    },
                    'Rollout Status': {
                        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                            sh "kubectl rollout status deployment/${deploymentName} --timeout=90s"
                        }
                    }
                )
            }
        }

    // stage('Integration Tests - DEV') {
    //   steps { 
    //     script { 
    //         // We use the 'file' credential method instead of 'withKubeConfig'
    //         withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
    //             try { 
    //                 sh "bash integration-test.sh" 
    //             } catch (e) { 
    //                 echo "Integration tests failed. Rolling back deployment..."
    //                 sh "kubectl -n default rollout undo deploy ${deploymentName}" 
    //                 throw e 
    //             } 
    //         }
    //     } 
    //   }
    // }

    stage('OWASP ZAP - DAST') {
    steps {
        // Use the standard file credential method
        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
            sh 'bash zap.sh'
        }
    }
}
    }

    post {
        always {
            junit 'target/surefire-reports/*.xml'
            jacoco execPattern: 'target/jacoco.exec'
            pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
            
            // Final cleanup of workspace permissions
            sh 'sudo chown -R jenkins:jenkins $WORKSPACE'
        }
        success {
            echo "Application is available at: ${applicationURL}${applicationURI}"
        }
    }
}
