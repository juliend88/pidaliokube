#!/usr/bin/env bash
i=0
until curl -m 5 http://localhost:8080/healthz || [[ $i == 5 ]]
do
    echo "Waiting for master to be ready"
    sleep 10
    i=$(expr $i + 1)
done
if [[ $i == 5 ]]; then exit 1; fi
# Initialize Kubernetes Addons
/opt/bin/kubectl create -f /etc/kubernetes/descriptors/dns
# Initialize Ceph
if [[ "${CEPH}" == "True" ]]
then
    /opt/pidalio/kube/kubelet/scripts/ceph/install-ceph.sh
    if [[ "${CEPH_DISK}" == "True" ]]
    then
        /opt/bin/kubectl --namespace=ceph create \
        -f /etc/kubernetes/descriptors/ceph/ceph-mds-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-mon-check-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-mon-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-mon-v1-svc.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-osd-v1-ds-disk.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-stats-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-stats-v1-svc.yaml
    else
        /opt/bin/kubectl --namespace=ceph create \
        -f /etc/kubernetes/descriptors/ceph/ceph-mds-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-mon-check-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-mon-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-mon-v1-svc.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-osd-v1-ds-dir.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-stats-v1-dp.yaml \
        -f /etc/kubernetes/descriptors/ceph/ceph-stats-v1-svc.yaml
    fi
    if [[ "${MONITORING}" == "True" ]]
    then
        until [ "$(/opt/bin/kubectl get pods --namespace=ceph | tail -n +2 | egrep -v '(.*)1/1(.*)Running' | wc -l)" == "0" ]
        do
          echo "Waiting for ceph to be ready"
          sleep 10
        done
        echo "Creating monitoring disk in ceph"
        until /opt/bin/rbd -m ceph-mon.ceph info prometheus
        do
          /opt/bin/rbd -m ceph-mon.ceph create prometheus --size=50G
        done
        until /opt/bin/rbd -m ceph-mon.ceph info grafana
        do
          /opt/bin/rbd -m ceph-mon.ceph create grafana --size=1G
        done
        /opt/bin/kubectl create -f /etc/kubernetes/descriptors/monitoring --namespace=monitoring
    fi
fi
# Initialize Toolbox
ssh-keygen -t rsa -f key
/opt/bin/kubectl create secret generic toolbox --from-file=ssh-privatekey=key --from-file=ssh-publickey=key.pub
rm -f key key.pub
# Openstack secrets
source /etc/openstack.env
OS_USERNAME=$(echo -n $OS_USERNAME | base64)
OS_PASSWORD=$(echo -n $OS_PASSWORD | base64)
OS_AUTH_URL=$(echo -n $OS_AUTH_URL | base64)
OS_TENANT_NAME=$(echo -n $OS_TENANT_NAME | base64)
cat <<EOF | kubectl create -f -
  apiVersion: v1
  kind: Secret
  metadata:
    name: openstack
  type: Opaque
  data:
    auth: $OS_AUTH_URL
    tenant: $OS_TENANT_NAME
    password: $OS_PASSWORD
    username: $OS_USERNAME
EOF
/opt/bin/kubectl create -f /etc/kubernetes/descriptors/toolbox/
exit 0
