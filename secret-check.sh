oc login --token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token) -s https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT --certificate-authority /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

while true; do
    SHA_SUM=""

    if [ -f ${SUBNETS_JSON} ]; then
        SHA_SUM=$(cat ${SUBNETS_JSON} | sha256sum)
    fi

    oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.subnets\.json}' | base64 -d > ${SUBNETS_JSON}.test

    if [ ! -z "${SHA_SUM}" ]; then
        TEST_SHA_SUM=$(cat ${SUBNETS_JSON}.test | sha256sum)

        if [[ $SHA_SUM != $TEST_SHA_SUM ]]; then
            echo change detected in secret, exiting
            exit 0
        fi
    fi
    mv ${SUBNETS_JSON}.test ${SUBNETS_JSON}
    echo no change detected, will check again in 30 seconds
    sleep 30
done