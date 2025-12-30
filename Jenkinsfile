pipeline {
    agent any


    stages {
        stage('Build - Maven') {
            steps {
                sh 'mvn clean package -DskipTests=true'
                archive 'target/*.jar'
            }
        }
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
        }
    }
}
