#!/usr/bin/env bash
set -exuv -o pipefail

USE_CRI=${USE_CRI:-crio} # available "crio", "docker", "containderd"
LOCAL_ETCD=${LOCAL_ETCD:-False}
# TODO wait https://github.com/aquasecurity/kube-bench/issues/335
USE_KUBEBENCH=False

VAGRANT_CFG=/vagrant/config/vagrant
mkdir -p ${VAGRANT_CFG}/kubernetes/

# TODO: Support dynamic ip ranges so 10.4 doesn't need to be hard coded.
# TODO: dynamically pull k8s-master1 address instead of hard coded.
LEAD_OCTETS=10.4
SERVER_IP=$(ip -f inet -o addr show | grep ${LEAD_OCTETS} | awk '{split($4,a,"/");print a[1]}' | tr -d '\n')
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
modprobe br_netfilter

if [[ "${LOCAL_ETCD}" == "False" ]]; then
    mkdir -p /var/lib/etcd
fi

chmod 0700 /var/lib/etcd
chmod 0700 /opt/cni/bin

if [[ "${LOCAL_ETCD}" != "False" ]]; then
    systemctl enable etcd
    systemctl restart etcd
fi

if [[ "${USE_CRI}" == "crio" ]]; then
    touch /var/lib/kubelet/config.yaml
    yq n /var/lib/kubelet/config.yaml cgroupDriver systemd
    echo "KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --node-ip=${SERVER_IP} --container-runtime-endpoint=unix:///var/run/crio/crio.sock --image-service-endpoint=unix:///var/run/crio/crio.sock" > /etc/default/kubelet
    systemctl enable crio
    systemctl restart crio
elif [[ "${USE_CRI}" == "docker" ]]; then
    echo "KUBELET_EXTRA_ARGS=--node-ip=${SERVER_IP}" > /etc/default/kubelet
    systemctl enable docker
    systemctl restart docker
elif [[ "${USE_CRI}" == "containerd" ]]; then
    echo "KUBELET_EXTRA_ARGS=--node-ip=${SERVER_IP}" > /etc/default/kubelet
    systemctl enable containerd
    systemctl restart containerd
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
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "${SERVER_IP}:6443"
apiServer.extraArgs.advertise-address: "${SERVER_IP}"
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

# kube-bench recommendations
# apiServer.extraArgs.anonymous-auth: "false"
# apiServer.extraArgs.repair-malformed-updates: "false"
apiServer.extraArgs.profiling: "false"
apiServer.extraArgs.admission-control-config-file: "/etc/kubernetes/pki/admission-control.conf"
# ,PodSecurityPolicy
apiServer.extraArgs.enable-admission-plugins: "NodeRestriction,EventRateLimit,ServiceAccount,AlwaysPullImages,SecurityContextDeny,DenyEscalatingExec"
apiServer.extraArgs.audit-log-path: "/var/log/kube-apiserver-audit.log"
apiServer.extraArgs.audit-log-maxage: "30"
apiServer.extraArgs.audit-log-maxbackup: "10"
apiServer.extraArgs.audit-log-maxsize: "100"
# apiServer.extraArgs.kubelet-certificate-authority: "/etc/kubernetes/pki/ca.crt"
apiServer.extraArgs.service-account-lookup: "true"
apiServer.extraArgs.tls-cipher-suites: "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256"

scheduler.extraArgs.profiling: "false"
controllerManager.extraArgs.profiling: "false"
controllerManager.extraArgs.terminated-pod-gc-threshold: "100"
controllerManager.extraArgs.feature-gates: "RotateKubeletServerCertificate=true"

EOF

mkdir -p /etc/kubernetes/pki/etcd/

# @TODO /etc/kubernetes/pki/ is ugly hack, maybe we need manual kubeadm init phase manifests and change VolumePath in kube-apiserver.yaml
cat > /etc/kubernetes/pki/admission-control.conf << EOF
kind: AdmissionConfiguration
apiVersion: apiserver.k8s.io/v1alpha1
plugins:
- name: EventRateLimit
  path: /etc/kubernetes/pki/admission-EventRateLimit.conf
EOF

# @TODO /etc/kubernetes/pki/ is ugly hack, maybe we need manual kubeadm init phase manifests and change VolumePath in kube-apiserver.yaml
cat > /etc/kubernetes/pki/admission-EventRateLimit.conf << EOF
kind: Configuration
apiVersion: eventratelimit.admission.k8s.io/v1alpha1
limits:
- type: Namespace
  qps: 100
  burst: 200
- type: User
  qps: 100
  burst: 200
EOF

KUBEADM_CLUSTER_CONFIG=${VAGRANT_CFG}/kubernetes/kubeadm-clusterconfig.yaml
KUBEADM_JOIN_CONFIG=${VAGRANT_CFG}/kubernetes/kubeadm-joinconfig.yaml
KUBEADM_CONFIG_MAP=${VAGRANT_CFG}/kubernetes/kubeadm-configmap.yaml

if hostnameMatches master1; then
    echo "apiVersion: kubeadm.k8s.io/v1beta2" > ${KUBEADM_CLUSTER_CONFIG}
    yq w -i -s ${TMPDIR}/kubeadm_init.yq ${KUBEADM_CLUSTER_CONFIG}

    KUBEADM_INIT="kubeadm init -v 2 --config ${KUBEADM_CLUSTER_CONFIG}"
    if [[ "${USE_CRI}" == "crio" ]]; then
        KUBEADM_INIT="${KUBEADM_INIT} --cri-socket=/var/run/crio/crio.sock"
    fi
    ${KUBEADM_INIT}

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    # remove kube-proxy
    if [[ "${USE_CRI}" == "crio" ]]; then
        while [[ "0" == $(crictl ps | grep kube-proxy | grep -i running | wc -l ) ]]; do
            echo "Kube-proxy is not yet ready"
            sleep 3
        done
        KUBE_PROXY_CID=$(crictl ps | grep kube-proxy | cut -d " " -f 1)
        crictl exec ${KUBE_PROXY_CID} kube-proxy --cleanup || true
    elif [[ "${USE_CRI}" == "docker" ]]; then
        while [[ "0" == $(docker ps | grep kube-proxy | grep -i running | wc -l ) ]]; do
            echo "Kube-proxy is not yet ready"
            sleep 3
        done
        K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-1.txt | tr -d '\n')
        docker run --rm --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy:${K8S_VERSION} kube-proxy --cleanup || true
    elif [[ "${USE_CRI}" == "containerd" ]]; then
        while [[ "0" == $(crictl ps | grep kube-proxy | grep -i running | wc -l ) ]]; do
            echo "Kube-proxy is not yet ready"
            sleep 3
        done
        K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-1.txt | tr -d '\n')
        ctr run --rm --privileged --mount type=bind,src=/lib/modules,dst=/lib/modules --net-host k8s.gcr.io/kube-proxy:${K8S_VERSION} kube-proxy --cleanup || true
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
    cp -fv /etc/kubernetes/pki/admission*.conf ${VAGRANT_CFG}/kubernetes/pki/
    # set correct public ip as adverticeAddress
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmaps -n kube-system kubeadm-config -o yaml > ${KUBEADM_CONFIG_MAP}
    KUBEADM_CONFIG_STATUS=$(yq r ${KUBEADM_CONFIG_MAP} data.ClusterStatus | yq w - apiEndpoints.${HOSTNAME}.advertiseAddress ${SERVER_IP})
    yq w -i ${KUBEADM_CONFIG_MAP} data.ClusterStatus "${KUBEADM_CONFIG_STATUS}"
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply --force -n kube-system -f ${KUBEADM_CONFIG_MAP}
    # Check after changing
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmaps -n kube-system kubeadm-config -o yaml > ${KUBEADM_CONFIG_MAP}
    cat ${KUBEADM_CONFIG_MAP} | grep "advertiseAddress:" | grep ${SERVER_IP}

    # If you add nodes later than 24 hours you will need to get a new kubeadm token.
    # Just run the following command on k8s-master1 before the vagrant up of a new node.
    KUBEADM_JOIN_TOKEN=$(kubeadm token create)
    KUBEADM_JOIN_CA=/etc/kubernetes/pki/ca.crt
    KUBEADM_JOIN_CA_SHA256=$(cat ${KUBEADM_JOIN_CA} | openssl x509 -pubkey -noout | openssl asn1parse -noout -inform pem -out ${TMPDIR}/kubeadm_join.key; openssl dgst -sha256 ${TMPDIR}/kubeadm_join.key | cut -d " " -f 2)

    cat > ${TMPDIR}/kubeadm_join.yq << EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
caCertPath: ${KUBEADM_JOIN_CA}
discovery.bootstrapToken.apiServerEndpoint: ${SERVER_IP}:6443
discovery.bootstrapToken.token: ${KUBEADM_JOIN_TOKEN}
discovery.bootstrapToken.caCertHashes[0]: "sha256:${KUBEADM_JOIN_CA_SHA256}"
controlPlane.localAPIEndpoint.advertiseAddress: ${SERVER_IP}
EOF
    echo "apiVersion: kubeadm.k8s.io/v1beta2" >  ${KUBEADM_JOIN_CONFIG}
    yq w -i -s ${TMPDIR}/kubeadm_join.yq ${KUBEADM_JOIN_CONFIG}

    truncate -s 0 ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
    KUBEADM_JOIN="kubeadm join"
#    if [[ "${USE_CRI}" == "crio" ]]; then
#        echo "${KUBEADM_JOIN} phase preflight --cri-socket=/var/run/crio/crio.sock -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
#        echo "${KUBEADM_JOIN} phase kubelet-start --cri-socket=/var/run/crio/crio.sock -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
#        echo "${KUBEADM_JOIN} phase control-plane-prepare all --cri-socket=/var/run/crio/crio.sock -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
#        echo "${KUBEADM_JOIN} phase control-plane-join all --cri-socket=/var/run/crio/crio.sock -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
#    else
        echo "${KUBEADM_JOIN} phase preflight -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
        echo "${KUBEADM_JOIN} phase kubelet-start -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
        echo "${KUBEADM_JOIN} phase control-plane-prepare all -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
        echo "${KUBEADM_JOIN} phase control-plane-join all -v 3 --config=${KUBEADM_JOIN_CONFIG}" >> ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
#    fi
fi

if hostnameMatches node; then
    while [ ! -f ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh ]; do
        echo "Kubernetes master is not yet ready"
        sleep 3
    done
    rm -rf /etc/kubernetes/*
    mkdir -p /etc/kubernetes/
    # Restore kubernetes node config from Vagrant shared folder
    # TODO: need more elastic solution
    cp -rfv ${VAGRANT_CFG}/kubernetes/* /etc/kubernetes

    echo "Kubernetes master is ready. Proceeding to join the cluster."
    cat > ${TMPDIR}/kubeadm_join.yq << EOF
controlPlane.localAPIEndpoint.advertiseAddress: ${SERVER_IP}
nodeRegistration.kubeletExtraArgs.node-ip: ${SERVER_IP}
EOF
    yq w -i -s ${TMPDIR}/kubeadm_join.yq ${KUBEADM_JOIN_CONFIG}
### ugly hack for public and private vagrant ip address
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
    yq w -i -s ${TMPDIR}/kubeadm_join.yq ${KUBEADM_JOIN_CONFIG}

    ETCD_INITIAL_CLUSTER_YML=$(yq r ${KUBEADM_CONFIG_MAP} data.ClusterConfiguration | yq w - etcd.local.extraArgs.initial-cluster "${ETCD_INITIAL_CLUSTER}")
    yq w -i ${KUBEADM_CONFIG_MAP} data.ClusterConfiguration "${ETCD_INITIAL_CLUSTER_YML}"
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply --force -n kube-system -f ${KUBEADM_CONFIG_MAP}

    # Check after changing
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmaps -n kube-system kubeadm-config -o yaml > ${KUBEADM_CONFIG_MAP}
    ETCD_INITIAL_CLUSTER_SAVED=$(yq r ${KUBEADM_CONFIG_MAP} data.ClusterConfiguration | yq r - etcd.local.extraArgs.initial-cluster)
    echo ${ETCD_INITIAL_CLUSTER_SAVED} | grep ${SERVER_IP}
    yq w -i ${KUBEADM_CLUSTER_CONFIG} etcd.local.extraArgs.initial-cluster "${ETCD_INITIAL_CLUSTER}"

    rm -rf /etc/kubernetes/manifests
    bash -x ${VAGRANT_CFG}/kubernetes/kubeadm-join.sh
fi

# Wait all components will up
while [[ "5" > "$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl -o wide -n kube-system get pods | grep -i ${HOSTNAME} | grep -E 'router|etcd|apiserver|controller|scheduler' | grep -i running | wc -l )" ]]; do
    echo "All Kubernetes pods on ${HOSTNAME} is not yet ready"
    sleep 3
done

sleep 10
KUBECONFIG=/etc/kubernetes/admin.conf kubectl taint nodes --all node-role.kubernetes.io/master- || true

KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -o wide --all-namespaces | grep ${HOSTNAME}

# security checks
if [[ "True" == "$USE_KUBEBENCH" ]]; then
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/master/job.yaml

    while [[ "0" == $(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -o wide | grep kube-bench | grep -i completed | wc -l) ]];
    do
        echo "Kube bench security check is not yet ready"
        sleep 3
    done
    KUBE_BENCH_POD=$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -o wide | grep kube-bench | grep -i completed | head -n 1 | cut -d " " -f 1)
    KUBE_BENCH_FAILS=$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl logs ${KUBE_BENCH_POD} | grep -E '\[FAIL\]')
    if [[ "0" != $(echo ${KUBE_BENCH_FAILS} | wc -l) ]]; then
        KUBECONFIG=/etc/kubernetes/admin.conf kubectl logs ${KUBE_BENCH_POD}
    fi
fi