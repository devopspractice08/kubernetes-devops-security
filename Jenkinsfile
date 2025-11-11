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
    }
}
