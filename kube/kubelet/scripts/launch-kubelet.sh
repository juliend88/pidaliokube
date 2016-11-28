#!/usr/bin/env bash
export DOCKER_HOST=unix:///var/run/weave/weave.sock
APISERVER_HOST=$(weave dns-lookup pidalio-apiserver)
mkdir -p /home/core/.kube
cat <<EOF > /home/core/.kube/config
apiVersion: v1
clusters:
- cluster:
    server: http://${APISERVER_HOST}:8080
  name: local
contexts:
- context:
    cluster: local
    user: local
  name: local
current-context: local
kind: Config
preferences: {}
users:
- name: local
EOF
chown -R core:core /home/core/.kube
(
    sleep 10
    until [[ "$(/usr/bin/curl -s -t 10 http://$APISERVER_HOST:8080/healthz)" != "ok" ]]
    do
        echo "API Server OK"
        sleep 10
    done
    /usr/bin/pkill kubelet
) &
echo "Setting DNS"
WEAVE_DNS_ADDRESS=$(/opt/bin/weave report | jq -r .DNS.Address | cut -d ':' -f 1)
cat <<EOF > /etc/resolv.conf
nameserver ${WEAVE_DNS_ADDRESS}
EOF
/opt/bin/kubelet \
    --network-plugin=cni \
    --network-plugin-dir=/etc/cni/net.d \
    --api-servers=https://pidalio-apiserver \
    --register-node=true \
    --node-labels=type=${NODE_TYPE},storage=${NODE_STORAGE},network=${NODE_NETWORK} \
    --allow-privileged=true \
    --node-ip=${NODE_IP} \
    --hostname-override=${NODE_PUBLIC_IP} \
    --cluster-dns=10.244.0.3 \
    --cluster-domain=${DOMAIN} \
    --kubeconfig=/etc/kubernetes/kubeconfig.yaml \
    --tls-cert-file=/etc/kubernetes/ssl/node.pem \
    --tls-private-key-file=/etc/kubernetes/ssl/node-key.pem
