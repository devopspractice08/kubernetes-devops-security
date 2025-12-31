#!/bin/bash
# trivy-k8s-scan.sh

echo "Scanning Image: $imageName"

# Create a .trivyignore file to skip the unfixable Spring-Web CVE
# This is necessary because Spring 5.x will not fix this (requires Java 17/Spring 6)
cat << EOF > .trivyignore
CVE-2016-1000027
EOF

# Run scan for LOW, MEDIUM, HIGH (Reports only, exit code 0)
docker run --rm \
    -v $WORKSPACE:/root/.cache/ \
    aquasec/trivy:0.17.2 -q image --light --severity LOW,MEDIUM,HIGH $imageName

# Run scan for CRITICAL (Fails build if any NEW criticals are found)
# Note: we mount the .trivyignore file into the container's root
docker run --rm \
    -v $WORKSPACE:/root/.cache/ \
    -v $(pwd)/.trivyignore:/.trivyignore \
    aquasec/trivy:0.17.2 -q image --exit-code 1 --severity CRITICAL --light $imageName

# Capture the exit code of the CRITICAL scan
exit_code=$?
echo "Trivy Exit Code : $exit_code"

if [[ ${exit_code} == 1 ]]; then
    echo "------------------------------------------------------------"
    echo "Image scanning failed. NEW Critical vulnerabilities found!"
    echo "------------------------------------------------------------"
    exit 1
else
    echo "------------------------------------------------------------"
    echo "Image scanning passed (Known unfixable CVEs ignored)."
    echo "------------------------------------------------------------"
    exit 0
fi
