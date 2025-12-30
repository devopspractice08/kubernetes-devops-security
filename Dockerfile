FROM eclipse-temurin:8-jre-jammy

# Create a system group and user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

# Ensure the appuser owns the directory
RUN chown appuser:appgroup /app

# Copy the jar
COPY target/*.jar app.jar

# Rule #7 compliance: Switch to non-root user
USER appuser

EXPOSE 8080

ENTRYPOINT ["java","-jar","app.jar"]
