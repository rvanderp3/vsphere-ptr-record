DNSMASQ_CONF=/tmp/dnsmasq.conf
SUBNETS_JSON=/tmp/subnets.json
oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.dnsmasq\.cfg}' | base64 -d > ${DNSMASQ_CONF}
SHA_SUM=""

## Legacy subnets
SUBNET_START=88
SUBNET_END=254

cat dnsmasq.conf | grep -v port >> ${DNSMASQ_CONF}

dnsmasq -C ${DNSMASQ_CONF}
while true; do
    TEST_SHA_SUM=$(oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data}' | sha256sum)

    if [[ $SHA_SUM != $TEST_SHA_SUM ]]; then        
        echo "config as ${SHA_SUM} now ${TEST_SHA_SUM}. updating hosts file." 
        oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.subnets\.json}' | base64 -d > ${SUBNETS_JSON}
        oc get secret -n test-credentials vsphere-config -o=jsonpath='{.data.dnsmasq\.cfg}' | base64 -d > ${DNSMASQ_CONF}
        rm /tmp/hosts2
        for SUBNET in $(seq $SUBNET_START $SUBNET_END); do
            for IP in $(seq 1 255); do
                echo "192.168.${SUBNET}.${IP} ${IP}.${SUBNET}.168.192.in-addr.arpa" >> /tmp/hosts2
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
                            echo "$IPADDRESS $(echo $IPADDRESS | rev).in-addr.arpa" >> /tmp/hosts2
                        done
                    done
                done        
            fi
        fi
        SHA_SUM=$TEST_SHA_SUM
        mv /tmp/hosts2 /tmp/hosts
        PID=$(cat /var/run/dnsmasq.pid)
        echo restarting dnsmasq $PID
        kill $PID
        retries=10
        while true; do
            if [ $retries -eq 0 ]; then
                echo exceeded retry count. exiting..
                exit 1
            fi
            dnsmasq -C ${DNSMASQ_CONF} -H /tmp/hosts        
            if [ $? -eq 0 ]; then
                break
            fi
            echo dnsmasq failed to restart, retrying in 1 second
            sleep 1
            retries=$((--retries))
        done
        echo new PID $(cat /var/run/dnsmasq.pid)
    fi
    echo no change detected, will check again in 30 seconds
    sleep 30
done