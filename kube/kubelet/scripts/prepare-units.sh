#!/usr/bin/env bash
source /etc/pidalio.env
for file in $(ls /opt/pidalio/kube/units/master/*.service)
do
    sed -i s/\\\$token\\\$/${PIDALIO_TOKEN}/g ${file}
    sed -i s/\\\$private_ipv4\\\$/${NODE_IP}/g ${file}
    sed -i s/\\\$public_ipv4\\\$/${NODE_PUBLIC_IP}/g ${file}
done
