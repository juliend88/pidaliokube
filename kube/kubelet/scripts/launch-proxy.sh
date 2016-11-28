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
    /usr/bin/docker rm -f pidalio-proxy
) &
/usr/bin/docker run \
    --volume /etc/kubernetes:/etc/kubernetes \
    --volume /usr/share/ca-certificates:/etc/ssl/certs \
    --volume /opt/pidalio/weave.dns:/etc/resolv.conf \
    --net=host \
    --privileged \
    --rm \
    --name=pidalio-proxy \
    quay.io/coreos/hyperkube:v1.4.6_coreos.0 \
    /hyperkube \
    kube-proxy \
    --master=https://pidalio-apiserver \
    --hostname-override=${NODE_PUBLIC_IP} \
    --kubeconfig=/etc/kubernetes/kubeconfig.yaml \
    --proxy-mode=iptables
