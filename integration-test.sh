#!/bin/bash
# integration-test.sh

sleep 10s # Increased sleep to ensure pod is fully ready

# 1. Get the NodePort
PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)

# 2. Get the IP Address (Removing http:// and any trailing ports/slashes)
# This extracts '3.108.200.102' from 'http://3.108.200.102:32523/'
IP_ADDR=$(echo $applicationURL | sed -e 's|^[^/]*//||' -e 's|[:/].*||')

echo "Detected Port: $PORT"
echo "Detected IP: $IP_ADDR"

# 3. Construct the clean URL
# We use the IP, the dynamic PORT from K8s, and the URI
FULL_URL="http://$IP_ADDR:$PORT$applicationURI"
echo "Testing URL: $FULL_URL"

if [[ ! -z "$PORT" ]];
then
    # Perform the request
    response=$(curl -s $FULL_URL)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" $FULL_URL)

    echo "Response Received: $response"
    echo "HTTP Code: $http_code"

    # Validation 1: Check if 99 + 1 = 100
    if [[ "$response" == "100" ]];
    then
        echo "Increment Test Passed"
    else
        echo "Increment Test Failed: Expected 100 but got $response"
        exit 1
    fi

    # Validation 2: Check HTTP Status
    if [[ "$http_code" == "200" ]];
    then
        echo "HTTP Status Code Test Passed"
    else
        echo "HTTP Status code is $http_code (Expected 200)"
        exit 1
    fi
else
    echo "Error: The Service ${serviceName} does not have a NodePort"
    exit 1
fi
