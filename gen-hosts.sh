## Legacy subnets
SUBNET_START=88
SUBNET_END=254

for SUBNET in $(seq $SUBNET_START $SUBNET_END); do
    for IP in $(seq 1 255); do
        echo "192.168.${SUBNET}.${IP} ${IP}.${SUBNET}.168.192.in-addr.arpa" >> hosts
    done
done

## VLAN based subnets config file
if [ -n ${SUBNETS_JSON} ]; then
    if [ -f ${SUBNETS_JSON} ]; then
        IPADDRESSES=$(cat ${SUBNETS_JSON} | jq -r .[].ipAddresses | grep -oP '"\K[^"]+' | grep -v ',')
        for IPADDRESS in ${IPADDRESSES}; do
            echo "$IPADDRESS $(echo $IPADDRESS | rev).in-addr.arpa" >> hosts
        done
    fi
fi

# start dnsmasq
dnsmasq -d -C dnsmasq.conf