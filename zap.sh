#!/bin/bash
# zap.sh

# 1. Get dynamic port and IP
PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)
IP_ADDR=$(echo $applicationURL | sed -e 's|^[^/]*//||' -e 's|[:/].*||')
ZAP_URL="http://$IP_ADDR:$PORT$applicationURI"

echo "ZAP is scanning: $ZAP_URL"

# 2. Fix permissions before running
# Sometimes previous runs leave a zap.yaml that ZAP can't overwrite
rm -f zap.yaml zap_report.html

# 3. Use the -p flag to pass the target directly, avoiding the YAML conflict
# We use 'zap-baseline.py' instead of the full automation framework to keep it simple
docker run --user root --rm \
    -v $(pwd):/zap/wrk/:rw \
    ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
    -t $ZAP_URL \
    -r zap_report.html

exit_code=$?

# 4. Check for report
if [ -f "zap_report.html" ]; then
    echo "ZAP scan finished successfully."
    # Change owner back to jenkins so post-actions don't fail
    sudo chown jenkins:jenkins zap_report.html
else
    echo "ZAP scan failed to generate a report."
    exit 1
fi

exit $exit_code
