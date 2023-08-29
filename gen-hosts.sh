SUBNET_START=88
SUBNET_END=254

for SUBNET in $(seq $SUBNET_START $SUBNET_END); do
    for IP in $(seq 1 255); do
        echo "192.168.${SUBNET}.${IP} ${IP}.${SUBNET}.168.192.in-addr.arpa" >> hosts
    done
done