#!/bin/bash
# zap.sh

# 1. Get dynamic port and IP
PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)
IP_ADDR=$(echo $applicationURL | sed -e 's|^[^/]*//||' -e 's|[:/].*||')
ZAP_URL="http://$IP_ADDR:$PORT$applicationURI"

echo "ZAP is scanning: $ZAP_URL"

# 2. Run ZAP with fixed permissions and HOME directory
# We add '-e HOME=/zap/wrk' so ZAP writes its config files in your workspace
docker run --user $(id -u):$(id -g) \
    -e HOME=/zap/wrk \
    --rm -v $(pwd):/zap/wrk/:rw \
    ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t $ZAP_URL \
    -r zap_report.html

exit_code=$?

# 3. Check for report
if [ -f "zap_report.html" ]; then
    echo "ZAP scan finished successfully."
else
    echo "ZAP scan failed to generate a report."
    exit 1
fi

exit $exit_code
