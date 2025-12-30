#!/bin/bash

# 1. Get the base image name from the first line of the Dockerfile
dockerImageName=$(awk 'NR==1 {print $2}' Dockerfile)
echo "Base image identified: $dockerImageName"

# 2. Run Trivy scan for HIGH vulnerabilities 
# We mount the cache to /tmp so it doesn't mess up the Jenkins workspace permissions
docker run --rm \
  -v /tmp/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.17.2 -q image --exit-code 0 --severity HIGH --light $dockerImageName

# 3. Run Trivy scan for CRITICAL vulnerabilities
# This one will return exit code 1 if it finds anything CRITICAL
docker run --rm \
  -v /tmp/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.17.2 -q image --exit-code 1 --severity CRITICAL --light $dockerImageName

# 4. Capture the exit code of the CRITICAL scan
exit_code=$?
echo "Trivy Scan Exit Code: $exit_code"

# 5. Process the result
if [[ "${exit_code}" == 1 ]]; then
    echo "Scan Result: CRITICAL vulnerabilities found. Failing the stage."
    exit 1
else
    echo "Scan Result: No CRITICAL vulnerabilities found. Proceeding..."
    exit 0
fi
