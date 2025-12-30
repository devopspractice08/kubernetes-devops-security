#!/bin/bash
set -e

IMAGE="shaikh7/numeric-app:${GIT_COMMIT}"

echo "Scanning image: $IMAGE"

# Trivy cache directory (isolated, safe)
mkdir -p /tmp/trivy-cache

# HIGH vulnerabilities (do not fail build)
docker run --rm \
  -v /tmp/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.52.0 \
  image --severity HIGH --exit-code 0 $IMAGE

# CRITICAL vulnerabilities (fail build)
docker run --rm \
  -v /tmp/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.52.0 \
  image --severity CRITICAL --exit-code 1 $IMAGE

echo "Trivy scan completed successfully"
