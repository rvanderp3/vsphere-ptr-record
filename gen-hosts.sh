oc login --token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token) -s https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT --certificate-authority /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.subnets\.json}' > ${SUBNETS_JSON}

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

cat /tmp/hosts

# start dnsmasq
dnsmasq -d -C dnsmasq.conf
