#!/bin/bash

# 1. Extract dynamic NodePort and IP for the test
# This ensures we are hitting the actual running app in K8s
PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)
IP_ADDR=$(echo $applicationURL | sed -e 's|^[^/]*//||' -e 's|[:/].*||')
ZAP_URL="http://$IP_ADDR:$PORT$applicationURI"

echo "--------------------------------------------"
echo "Starting OWASP ZAP DAST Scan"
echo "Target URL: $ZAP_URL"
echo "--------------------------------------------"

# 2. Cleanup old files
# ZAP can crash if it finds an existing zap.yaml or report it can't overwrite
rm -f zap_report.html zap.yaml

# 3. Run ZAP Baseline Scan
# -e HOME=/zap/wrk tells ZAP to use the workspace for temp files (fixes permission errors)
# --user root ensures Docker can write the report back to your Jenkins workspace
docker run --user root \
    -e HOME=/zap/wrk \
    --rm -v $(pwd):/zap/wrk/:rw \
    ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t $ZAP_URL \
    -r zap_report.html

exit_code=$?

echo "--------------------------------------------"
echo "ZAP Scan Finished with Exit Code: $exit_code"

# 4. Final Logic and Permissions
if [ -f "zap_report.html" ]; then
    echo "Report generated successfully: zap_report.html"
    # Change owner back to jenkins so the post-build archive step works
    sudo chown jenkins:jenkins zap_report.html
else
    echo "ERROR: ZAP failed to generate the report file."
    exit 1
fi

# 5. Pipeline Gate Logic
# ZAP Exit Codes:
# 0: Success (No warnings/errors)
# 1: Tool Error
# 2: Success (But warnings found)
if [ $exit_code -eq 0 ] || [ $exit_code -eq 2 ]; then
    echo "ZAP Result: PASS (or minor warnings). Continuing pipeline..."
    exit 0
else
    echo "ZAP Result: FAIL. Serious vulnerabilities or errors found."
    exit 1
fi
