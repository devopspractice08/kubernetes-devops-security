#!/bin/bash
set -e

IMAGE="shaikh7/numeric-app:${GIT_COMMIT}"
echo "Scanning image: $IMAGE"

# Create cache dir INSIDE the workspace (safe for Docker context)
mkdir -p trivy-cache

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.52.0 \
  image --scanners vuln --severity HIGH --exit-code 0 $IMAGE

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.52.0 \
  image --scanners vuln --severity CRITICAL --exit-code 1 $IMAGE

echo "Trivy scan completed"
