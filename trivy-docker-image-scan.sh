#!/bin/bash
set -e

IMAGE="shaikh7/numeric-app:${GIT_COMMIT}"

echo "Scanning image: $IMAGE"

mkdir -p /tmp/trivy-cache

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.52.0 \
  image --scanners vuln --severity HIGH --exit-code 0 $IMAGE

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/trivy-cache:/root/.cache/ \
  aquasec/trivy:0.52.0 \
  image --scanners vuln --severity CRITICAL --exit-code 1 $IMAGE

echo "Trivy scan completed"
