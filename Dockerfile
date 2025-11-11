# Use valid OpenJDK 17 image
FROM openjdk:17-jdk-slim

# Expose port
EXPOSE 8080

# Argument for jar file
ARG JAR_FILE=target/*.jar

# Copy the jar into image
ADD ${JAR_FILE} app.jar

# Run the jar
ENTRYPOINT ["java","-jar","/app.jar"]
