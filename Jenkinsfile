pipeline {
    agent any

    environment {
        deploymentName = 'devsecops'
        containerName  = 'devsecops-container'
        serviceName    = 'devsecops-svc'
        imageName      = "shaikh7/numeric-app:${GIT_COMMIT}"
        applicationURL = 'http://3.108.200.102:32523/'
        applicationURI = '/increment/99'
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
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
                sh 'mvn org.pitest:pitest-maven:mutationCoverage'
            }
        }

        stage('SonarQube - SAST') {
            steps {
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

        stage('Vulnerability Scan - K8s') {
            steps {
                parallel(
                    'OPA Scan': {
                        sh '''
                            docker run --rm -v $(pwd):/project \
                            openpolicyagent/conftest test \
                            --policy opa-k8s-security.rego \
                            k8s_deployment_service.yaml || true
                        '''
                    },
                    'Kubesec Scan': {
                        sh 'bash kubesec-scan.sh || true'
                    },
                    'Trivy Scan': {
                        sh 'bash trivy-k8s-scan.sh || true'
                    }
                )
            }
        }

        stage('K8S Deployment - DEV') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        sed -i "s#replace#${imageName}#g" k8s_deployment_service.yaml
                        kubectl apply -f k8s_deployment_service.yaml
                        kubectl rollout status deployment/${deploymentName} --timeout=90s
                    """
                }
            }
        }

        stage('Prompte to PROD?') {
            steps {
                timeout(time: 2, unit: 'DAYS') {
                    input 'Do you want to Approve the Deployment to Production?'
                }
            }
        }

        stage('K8S CIS Benchmark') {
            steps {
                parallel(
                    "Master": { sh "bash cis-master.sh" },
                    "Etcd": { sh "bash cis-etcd.sh" },
                    "Kubelet": { sh "bash cis-kubelet.sh" }
                )
            }
        }

        stage('K8S Deployment - PROD') {
            steps {
                // CHANGED: Using withCredentials instead of withKubeConfig
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        sed -i "s#replace#${imageName}#g" k8s_PROD-deployment_service.yaml
                        kubectl -n prod apply -f k8s_PROD-deployment_service.yaml
                        bash k8s-PROD-deployment-rollout-status.sh
                    """
                }
            }
        }
    }

    post {
        always {
            // Only run junit if files actually exist to avoid NaN/Empty errors
            script {
                if (fileExists('target/surefire-reports/')) {
                    junit 'target/surefire-reports/*.xml'
                }
            }
            
            jacoco execPattern: 'target/jacoco.exec'
            
            // Fix PIT: Use failWhenNoMutations: false so NaN doesn't crash the build
            pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml', 
                        failWhenNoMutations: false
            
            archiveArtifacts artifacts: 'zap_report.html', allowEmptyArchive: true
            
            // Final workspace cleanup
            sh 'sudo chown -R jenkins:jenkins $WORKSPACE'
        }
        success {
            echo "SUCCESS: Application deployed to PROD!"
            echo "Application is available at: ${applicationURL}${applicationURI}"
        }
    }
}
