#!/usr/bin/env bash
export DOCKER_HOST=unix:///var/run/weave/weave.sock
APISERVER_HOST=$(weave dns-lookup pidalio-apiserver)
(
    sleep 10
    until [[ "$(/usr/bin/curl -s -t 10 http://$APISERVER_HOST:8080/healthz)" != "ok" ]]
    do
        echo "API Server OK"
        sleep 10
    done
    /usr/bin/pkill kube-proxy
) &
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