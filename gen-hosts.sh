oc login --token $(cat /var/run/secrets/kubernetes.io/serviceaccount/token) -s https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT --certificate-authority /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

DNSMASQ_CONF=/tmp/dnsmasq.conf
oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.subnets\.json}' | base64 -d > ${SUBNETS_JSON}
oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.dnsmasq\.cfg}' | base64 -d > ${DNSMASQ_CONF}
SHA_SUM="$(oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data}' | sha256sum)"
echo "config hash $SHA_SUM"

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
        DATACENTERS=($(cat ${SUBNETS_JSON} | jq -r 'keys | join(" ")'))
        for DATACENTER in ${DATACENTERS[@]}; do    
            VLANS=($(cat ${SUBNETS_JSON} | jq -r --arg DATACENTER "${DATACENTER}" '.[$DATACENTER] | keys | join(" ")'))
            for VLAN in ${VLANS[@]}; do
                IPADDRESSES=($(cat ${SUBNETS_JSON} | jq -r --arg DATACENTER "${DATACENTER}" --arg VLAN "${VLAN}" '.[$DATACENTER] | .[$VLAN] | .["ipAddresses"] | join(" ")'))
                for IPADDRESS in ${IPADDRESSES[@]}; do
                    echo "$IPADDRESS $(echo $IPADDRESS | rev).in-addr.arpa" >> /tmp/hosts
                done
            done
        done        
    fi
fi

cat dnsmasq.conf >> ${DNSMASQ_CONF}

# start dnsmasq
dnsmasq -C ${DNSMASQ_CONF}

while true; do
    TEST_SHA_SUM=$(oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data}' | sha256sum)

    if [[ $SHA_SUM != $TEST_SHA_SUM ]]; then
        echo change detected in secret ${TEST_SHA_SUM}, exiting
        exit 0
    fi
    echo no change detected, will check again in 30 seconds
    sleep 30
done

DATACENTERS=($(cat /tmp/subnets.json | jq -r 'keys | join(" ")'))
for DATACENTER in ${DATACENTERS[@]}; do    
    VLANS=($(cat /tmp/subnets.json | jq -r --arg DATACENTER "${DATACENTER}" '.[$DATACENTER] | keys | join(" ")'))
    for VLAN in ${VLANS[@]}; do
        ADDRESSES=($(cat /tmp/subnets.json | jq -r --arg DATACENTER "${DATACENTER}" --arg VLAN "${VLAN}" '.[$DATACENTER] | .[$VLAN] | .["ipAddresses"] | join(" ")'))
    done
done
# cat /tmp/subnets.json | jq -r --arg DATACENTER "${DATACENTERS[0]}" '.[$DATACENTER]'