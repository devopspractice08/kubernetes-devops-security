#!/bin/bash
# zap.sh

# 1. Get dynamic port and IP (consistent with your integration tests)
PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)
IP_ADDR=$(echo $applicationURL | sed -e 's|^[^/]*//||' -e 's|[:/].*||')
ZAP_URL="http://$IP_ADDR:$PORT$applicationURI"

echo "ZAP is scanning: $ZAP_URL"

# 2. Run ZAP using the new official GitHub Container Registry image
# We mount the current directory to /zap/wrk so the report is saved to your workspace
docker run --user $(id -u):$(id -g) --rm -v $(pwd):/zap/wrk/:rw \
    ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t $ZAP_URL \
    -r zap_report.html

exit_code=$?

# 3. Check if the report was actually created before trying to use it
if [ -f "zap_report.html" ]; then
    echo "ZAP scan finished successfully. Report generated."
else
    echo "ZAP scan failed to generate a report. Check if the URL is reachable."
    exit 1
fi

echo "Exit Code : $exit_code"

# ZAP baseline returns 1 if it finds warnings, 0 if clean.
# Usually, in DevSecOps, we allow 1 but fail on 2+ (errors).
if [[ ${exit_code} -ge 2 ]]; then
    echo "OWASP ZAP found significant security risks!"
    exit 1
else
    echo "OWASP ZAP scan completed."
    exit 0
fi
