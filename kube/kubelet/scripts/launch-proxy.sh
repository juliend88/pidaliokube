#!/usr/bin/env bash
echo "Setting DNS"
WEAVE_DNS_ADDRESS=$(/opt/bin/weave report | jq -r .DNS.Address | cut -d ':' -f 1)
cat <<EOF > /etc/resolv.conf
nameserver ${WEAVE_DNS_ADDRESS}
nameserver 185.23.94.244
EOF
/opt/bin/kube-proxy \
  --master=https://pidalio-apiserver \
  --hostname-override=${NODE_PUBLIC_IP} \
  --kubeconfig=/etc/kubernetes/kubeconfig.yaml \
  --proxy-mode=iptables
