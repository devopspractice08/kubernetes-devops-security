pipeline {
    agent any


    stages {
        stage('Build - Maven') {
            steps {
                sh 'mvn clean package -DskipTests=true'
                archive 'target/*.jar'
            }
        }
        stage('Unit Tests & Coverage') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    // Publish JUnit results
                    junit 'target/surefire-reports/*.xml'
                    // Publish JaCoCo coverage
                    jacoco execPattern: 'target/jacoco.exec'
                }
            }
        }
    }
}
