#!/bin/bash

# Extract the base image from Dockerfile
dockerImageName=$(awk 'NR==1 {print $2}' Dockerfile)
echo "Scanning Base Image: $dockerImageName"

# Create a specific directory for trivy cache to avoid permission errors in workspace root
mkdir -p $WORKSPACE/trivy-cache

# Run Trivy scans
# Scan 1: High vulnerabilities (won't fail the build)
docker run --rm -v $WORKSPACE/trivy-cache:/root/.cache/ aquasec/trivy:0.17.2 -q image --exit-code 0 --severity HIGH --light $dockerImageName

# Scan 2: Critical vulnerabilities (will fail the build if found)
docker run --rm -v $WORKSPACE/trivy-cache:/root/.cache/ aquasec/trivy:0.17.2 -q image --exit-code 1 --severity CRITICAL --light $dockerImageName

# Capture exit code of the CRITICAL scan
exit_code=$?
echo "Trivy Exit Code : $exit_code"

if [[ "${exit_code}" == 1 ]]; then
    echo "Image scanning failed. CRITICAL vulnerabilities found."
    exit 1
else
    echo "Image scanning passed. No CRITICAL vulnerabilities found."
    exit 0
fi
