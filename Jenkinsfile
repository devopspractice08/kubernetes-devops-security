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
      post {
        always {
          junit 'target/surefire-reports/*.xml'
          jacoco execPattern: 'target/jacoco.exec'
        }
      }
    }

  stage('Mutation Tests - PIT') {
      steps {
        sh 'mvn org.pitest:pitest-maven:mutationCoverage'
      }
      post {
        always {
          pitmutation mutationStatsFile: '**/target/pit-reports/**/mutations.xml'
        }
      }
    }
    
    stage('Docker Build & Push') {
      steps {
        withDockerRegistry([credentialsId: 'docker-hub', url: '']) {
          sh 'docker build -t shaikh7/numeric-app:${GIT_COMMIT} .'
          sh 'docker push shaikh7/numeric-app:${GIT_COMMIT}'
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
}
