#!/usr/bin/env bash
set -exuv -o pipefail

USE_DOCKER=False
LOCAL_ETCD=False

VAGRANT_CFG=/vagrant/config/vagrant
# TODO: Support dynamic ip ranges so 10.4 doesnt need to be hard coded.
# TODO: dynamically pull k8s-master1 address instead of hard coded.
LEAD_OCTETS=10.4
SERVER_IP=$(ip -f inet -o addr show | grep ${LEAD_OCTETS} | awk '{split($4,a,"/");print a[1]}' | tr -d '\n')
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
modprobe br_netfilter

if [[ "${LOCAL_ETCD}" != "False" ]]; then
    systemctl enable etcd
    systemctl restart etcd
fi

if [[ "${USE_DOCKER}" == "False" ]]; then
    touch /var/lib/kubelet/config.yaml
    yq n /var/lib/kubelet/config.yaml cgroupDriver systemd
    echo "KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --node-ip=${SERVER_IP} --container-runtime-endpoint=unix:///var/run/crio/crio.sock --image-service-endpoint=unix:///var/run/crio/crio.sock" > /etc/default/kubelet
    systemctl enable crio
    systemctl restart crio
else
    echo "KUBELET_EXTRA_ARGS=--node-ip=${SERVER_IP}" > /etc/default/kubelet
    systemctl enable docker
    systemctl restart docker
fi

systemctl daemon-reload

systemctl enable kubelet
systemctl restart kubelet

hostnameMatches() {
    hostname | grep $1 > /dev/null
    return $?
}

TMPDIR=$(mktemp -d)

cat > ${TMPDIR}/kubeadm_init.yq << EOF
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "${SERVER_IP}:6443"
apiServer.extraArgs.advertise-address: "${SERVER_IP}"
apiServer.extraArgs.anonymous-auth: "true"
apiServer.extraArgs.enable-aggregator-routing: "true"
controllerManager.extraArgs.allocate-node-cidrs: "true"
controllerManager.extraArgs.service-cluster-ip-range: "10.99.0.0/16"
networking.podSubnet: "10.244.0.0/16"
networking.serviceSubnet: "10.99.0.0/16"
etcd.local.extraArgs.initial-cluster: "${HOSTNAME}=https://${SERVER_IP}:2380"
etcd.local.extraArgs.advertise-client-urls: "https://${SERVER_IP}:2379"
etcd.local.extraArgs.initial-advertise-peer-urls: "https://${SERVER_IP}:2380"
etcd.local.extraArgs.listen-client-urls: "https://0.0.0.0:2379"
etcd.local.extraArgs.listen-peer-urls: "https://0.0.0.0:2380"
etcd.local.serverCertSANs[+]: ${SERVER_IP}
etcd.local.peerCertSANs[+]: ${SERVER_IP}
EOF


KUBEADM_CLUSTER_CONFIG=${VAGRANT_CFG}/kubernetes/kubeadm-clusterconfig.yaml
KUBEADM_JOIN_CONFIG=${VAGRANT_CFG}/kubernetes/kubeadm-joinconfig.yaml
KUBEADM_CONFIG_MAP=${VAGRANT_CFG}/kubernetes/kubeadm-configmap.yaml

if hostnameMatches master1; then
    echo "apiVersion: kubeadm.k8s.io/v1beta1" > ${KUBEADM_CLUSTER_CONFIG}
    yq w -i -s ${TMPDIR}/kubeadm_init.yq ${KUBEADM_CLUSTER_CONFIG}

    KUBEADM_INIT="kubeadm init -v 2 --config ${KUBEADM_CLUSTER_CONFIG}"
    if [[ "${USE_DOCKER}" == "False" ]]; then
        KUBEADM_INIT="${KUBEADM_INIT} --cri-socket=/var/run/crio/crio.sock"
    fi
    ${KUBEADM_INIT}

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    # remove kube-proxy
    if [[ "${USE_DOCKER}" == "False" ]]; then
        while [[ "0" == $(crictl ps | grep kube-proxy | grep -i running | wc -l ) ]]; do
            echo "Kube-proxy is not yet ready"
            sleep 3
        done
        KUBE_PROXY_CID=$(crictl ps | grep kube-proxy | cut -d " " -f 1)
        crictl exec ${KUBE_PROXY_CID} kube-proxy --cleanup || true
    else
        while [[ "0" == $(docker ps | grep kube-proxy | grep -i running | wc -l ) ]]; do
            echo "Kube-proxy is not yet ready"
            sleep 3
        done
        K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-1.txt | tr -d '\n')
        docker run --rm --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy:${K8S_VERSION} kube-proxy --cleanup || true
    fi
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system delete ds kube-proxy

    # Install kube-router networking.
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml

    # Install wave networking
    # KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

    # save PKI to /vagrant
    mkdir -p -v ${VAGRANT_CFG}/kubernetes/pki/etcd/
    cp -fv /etc/kubernetes/pki/ca.crt ${VAGRANT_CFG}/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/ca.key ${VAGRANT_CFG}/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/sa.key ${VAGRANT_CFG}/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/sa.pub ${VAGRANT_CFG}/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/front-proxy-ca.crt ${VAGRANT_CFG}/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/front-proxy-ca.key ${VAGRANT_CFG}/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/etcd/ca.crt ${VAGRANT_CFG}/kubernetes/pki/etcd/
    cp -fv /etc/kubernetes/pki/etcd/ca.key ${VAGRANT_CFG}/kubernetes/pki/etcd/
    cp -fv /etc/kubernetes/admin.conf ${VAGRANT_CFG}/kubernetes/

    KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmaps -n kube-system kubeadm-config -o yaml > ${KUBEADM_CONFIG_MAP}
    KUBEADM_CONFIG_STATUS=$(yq r ${KUBEADM_CONFIG_MAP} data.ClusterStatus | yq w - apiEndpoints.${HOSTNAME}.advertiseAddress ${SERVER_IP})
    yq w -i ${KUBEADM_CONFIG_MAP} data.ClusterStatus "${KUBEADM_CONFIG_STATUS}"
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply --force -n kube-system -f ${KUBEADM_CONFIG_MAP}
    # Check after changing
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmaps -n kube-system kubeadm-config -o yaml | grep "advertiseAddress:" | grep ${SERVER_IP}

    # Wait all components will up
    while [[ "6" > "$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system get pods | grep -E 'router|etcd|coredns|apiserver|controller|scheduler' | grep -i running | wc -l )" ]]; do
        echo "All Kubernetes pods is not yet ready"
        sleep 3
    done
    # If you add nodes later you will need to get a new kubeadm token.
    # Just run the following command on k8s-master1 before the vagrant up of a new node.
    KUBEADM_JOIN_TOKEN=$(kubeadm token create)
    KUBEADM_JOIN_CA=/etc/kubernetes/pki/ca.crt
    KUBEADM_JOIN_CA_SHA256=$(cat ${KUBEADM_JOIN_CA} | openssl x509 -pubkey -noout | openssl asn1parse -noout -inform pem -out ${TMPDIR}/kubeadm_join.key; openssl dgst -sha256 ${TMPDIR}/kubeadm_join.key | cut -d " " -f 2)

    KUBEADM_JOIN="kubeadm join -v 3 --experimental-control-plane"
    if [[ "${USE_DOCKER}" == "False" ]]; then
        KUBEADM_JOIN="${KUBEADM_JOIN} --cri-socket=/var/run/crio/crio.sock"
    fi

    cat > ${TMPDIR}/kubeadm_join.yq << EOF
apiVersion: kubeadm.k8s.io/v1beta1
kind: JoinConfiguration
caCertPath: ${KUBEADM_JOIN_CA}
discovery.bootstrapToken.apiServerEndpoint: ${SERVER_IP}:6443
discovery.bootstrapToken.token: ${KUBEADM_JOIN_TOKEN}
discovery.bootstrapToken.caCertHashes[0]: "sha256:${KUBEADM_JOIN_CA_SHA256}"
controlPlane.localAPIEndpoint.advertiseAddress: ${SERVER_IP}:6443
EOF
    echo "apiVersion: kubeadm.k8s.io/v1beta1" >  ${KUBEADM_JOIN_CONFIG}
    yq w -i -s ${TMPDIR}/kubeadm_join.yq ${KUBEADM_JOIN_CONFIG}
    echo "${KUBEADM_JOIN} --config=${KUBEADM_JOIN_CONFIG} --ignore-preflight-errors=DirAvailable--etc-kubernetes-manifests" > ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
fi

if hostnameMatches node; then
    while [ ! -f ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh ]; do
        echo "Kubernetes master is not yet ready"
        sleep 3
    done
    rm -rf /etc/kubernetes/*
    mkdir -p /etc/kubernetes/
    cp -rfv ${VAGRANT_CFG}/kubernetes/* /etc/kubernetes/

    echo "Kubernetes master is ready. Proceeding to join the cluster."
    cat > ${TMPDIR}/kubeadm_join.yq << EOF
controlPlane.localAPIEndpoint.advertiseAddress: ${SERVER_IP}
nodeRegistration.kubeletExtraArgs.node-ip: ${SERVER_IP}
EOF
    yq w -i -s ${TMPDIR}/kubeadm_join.yq ${KUBEADM_JOIN_CONFIG}
    ETCD_INITIAL_CLUSTER=$(yq r ${KUBEADM_CLUSTER_CONFIG} etcd.local.extraArgs.initial-cluster)
    if [[ "0" == "$(echo ${ETCD_INITIAL_CLUSTER} | grep -q ${HOSTNAME} | wc -l)" ]]; then
        ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER},${HOSTNAME}=https://${SERVER_IP}:2380"
    fi
    cat > ${TMPDIR}/kubeadm_join.yq << EOF
etcd.local.extraArgs.initial-cluster: "${ETCD_INITIAL_CLUSTER}"
etcd.local.extraArgs.listen-client-urls: https://${SERVER_IP}:2379
etcd.local.extraArgs.listen-peer-urls: https://${SERVER_IP}:2379
etcd.local.extraArgs.initial-cluster-state: existing
etcd.local.serverCertSANs[0]: ${SERVER_IP}
etcd.local.peerCertSANs[0]: ${SERVER_IP}
EOF
    yq w -i -s ${TMPDIR}/kubeadm_join.yq ${KUBEADM_CLUSTER_CONFIG}


    kubeadm init phase certs etcd-server --config=${KUBEADM_CLUSTER_CONFIG}
    kubeadm init phase certs etcd-peer --config=${KUBEADM_CLUSTER_CONFIG}
    kubeadm init phase certs etcd-healthcheck-client --config=${KUBEADM_CLUSTER_CONFIG}
    kubeadm init phase certs apiserver-etcd-client --config=${KUBEADM_CLUSTER_CONFIG}
    kubeadm init phase etcd local --config=${KUBEADM_CLUSTER_CONFIG}

    ETCD_INITIAL_CLUSTER_YML=$(yq r ${KUBEADM_CONFIG_MAP} data.ClusterConfiguration | yq w - etcd.local.extraArgs.initial-cluster "${ETCD_INITIAL_CLUSTER}")
    yq w -i ${KUBEADM_CONFIG_MAP} data.ClusterConfiguration "${ETCD_INITIAL_CLUSTER_YML}"
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply --force -n kube-system -f ${KUBEADM_CONFIG_MAP}

    bash -x ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
fi

sleep 10
# KUBECONFIG=/etc/kubernetes/admin.conf kubectl taint nodes --all node-role.kubernetes.io/master- || true
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -o wide --all-namespaces --include-uninitialized
