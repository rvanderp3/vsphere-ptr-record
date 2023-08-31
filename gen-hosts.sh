oc login --token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token) -s https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT --certificate-authority /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

DNSMASQ_CONF=/tmp/dnsmasq.conf
oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.subnets\.json}' | base64 -d > ${SUBNETS_JSON}
oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.dnsmasq\.cfg}' | base64 -d > ${DNSMASQ_CONF}

## Legacy subnets
SUBNET_START=88
SUBNET_END=254

for SUBNET in $(seq $SUBNET_START $SUBNET_END); do
    for IP in $(seq 1 255); do
        echo "192.168.${SUBNET}.${IP} ${IP}.${SUBNET}.168.192.in-addr.arpa" >> /tmp/hosts
    done
done

## VLAN based subnets config file
if [ -n ${SUBNETS_JSON} ]; then
    echo "checking for ${SUBNETS_JSON}"
    if [ -f ${SUBNETS_JSON} ]; then
        echo "parsing ${SUBNETS_JSON}"
        IPADDRESSES=$(cat ${SUBNETS_JSON} | jq -r .[].ipAddresses | grep -oP '"\K[^"]+' | grep -v ',')
        for IPADDRESS in ${IPADDRESSES}; do
            echo "$IPADDRESS $(echo $IPADDRESS | rev).in-addr.arpa" >> /tmp/hosts
        done
    fi
fi

cat dnsmasq.conf >> ${DNSMASQ_CONF}

# start dnsmasq
dnsmasq -C ${DNSMASQ_CONF}

while true; do
    SHA_SUM=""

    if [ -f ${SUBNETS_JSON} ]; then
        SHA_SUM=$(cat ${SUBNETS_JSON} | sha256sum)
    fi

    oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data}' > ${SUBNETS_JSON}.test

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