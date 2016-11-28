#!/usr/bin/env bash
mkdir -p /home/core/.kube
APISERVER_HOST=$(weave dns-lookup pidalio-apiserver)
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
export DOCKER_HOST=unix:///var/run/weave/weave.sock
/usr/bin/docker pull quay.io/coreos/hyperkube:v1.4.6_coreos.0
/usr/bin/docker run \
    --volume /var/lib/docker:/var/lib/docker \
    --volume /var/lib/kubelet:/var/lib/kubelet \
    --volume /usr/lib/os-release:/usr/lib/os-release \
    --volume /run:/run \
    --volume /etc/cni:/etc/cni \
    --volume /var/log:/var/log \
    --volume /etc/kubernetes:/etc/kubernetes \
    --volume /usr/share/ca-certificates:/etc/ssl/certs \
    --volume /opt/pidalio/weave.dns:/etc/resolv.conf \
    --net=host \
    --privileged \
    --rm \
    --name=pidalio-node \
    quay.io/coreos/hyperkube:v1.4.6_coreos.0 \
    /hyperkube \
    kubelet \
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
