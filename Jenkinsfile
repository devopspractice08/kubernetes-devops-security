pipeline {
  agent any

  stages {

    stage('Build Artifact - Maven') {
      steps {
        sh 'mvn clean package -DskipTests=true'
        archiveArtifacts 'target/*.jar'
      }
    }

    stage('Unit Tests - JUnit & JaCoCo') {
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
        sh '''
          mvn clean verify sonar:sonar \
          -Dsonar.projectKey=numeric-application \
          -Dsonar.host.url=http://3.108.200.102:9000 \
          -Dsonar.login=sqp_f60bb81b6ffeeb7ffd83d5a782c18cdd6efd784b
        '''
      }
    }

   stage('Vulnerability Scan - Docker') {
      steps {
        parallel(
          'Dependency Scan (OWASP)': {
            sh 'mvn dependency-check:check -DskipTests=true || true'
          },
          'Trivy Image Scan': {
            sh '''
              sh "chmod +x trivy-docker-image-scan.sh
              ./trivy-docker-image-scan.sh"
            '''
          }
        )
      }
    }
    stage('Docker Build & Push') {
      steps {
        withDockerRegistry([credentialsId: 'docker-hub', url: '']) {
          sh '''
            docker build -t shaikh7/numeric-app:${GIT_COMMIT} .
            docker push shaikh7/numeric-app:${GIT_COMMIT}
          '''
        }
      }
    }

    stage('Kubernetes Deployment - DEV') {
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
      dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
    }
  }
}
