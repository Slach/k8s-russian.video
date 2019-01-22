#!/usr/bin/env bash
set -exuv -o pipefail

USE_DOCKER=False
LOCAL_ETCD=False

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

cat > ${TMPDIR}/kubeadm.yq << EOF
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
etcd.local.extraArgs.name: ${HOSTNAME}
etcd.local.extraArgs.initial-cluster: "${HOSTNAME}=https://${SERVER_IP}:2380"
etcd.local.extraArgs.initial-cluster-state: new
etcd.local.extraArgs.advertise-client-urls: "https://${SERVER_IP}:2379"
etcd.local.extraArgs.initial-advertise-peer-urls: "https://${SERVER_IP}:2380"
etcd.local.extraArgs.listen-client-urls: "https://0.0.0.0:2379"
etcd.local.extraArgs.listen-peer-urls: "https://0.0.0.0:2380"
etcd.local.serverCertSANs[+]: ${SERVER_IP}
etcd.local.peerCertSANs[+]: ${SERVER_IP}
EOF

if hostnameMatches master1; then
    KUBEADM_YML=/vagrant/config/vagrant/kubeadm-ha.yaml
    echo "apiVersion: kubeadm.k8s.io/v1beta1" > ${KUBEADM_YML}
    yq w -i -s ${TMPDIR}/kubeadm.yq ${KUBEADM_YML}

    KUBEADM_INIT="kubeadm init -v 2 --config /vagrant/config/vagrant/kubeadm-ha.yaml"
    if [[ "${USE_DOCKER}" == "False" ]]; then
        KUBEADM_INIT="${KUBEADM_INIT} --cri-socket=/var/run/crio/crio.sock"
    fi
    ${KUBEADM_INIT}

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    # remove kube-proxy
    # KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system -o yaml describe ds kube-proxy > /tmp/kube-proxy.yaml
    if [[ "${USE_DOCKER}" == "False" ]]; then
        while [[ "0" == $(crictl ps | grep kube-proxy | grep -i running | wc -l ) ]]; do
            echo "Kube-proxy is not yet ready"
            sleep 3
        done
        KUBE_PROXY_CID=$(crictl ps | grep kube-proxy | cut -d " " -f 1)
        crictl exec ${KUBE_PROXY_CID} kube-proxy --cleanup || true
    else
        K8S_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-1.txt | tr -d '\n')
        docker run --rm --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy:${K8S_VERSION} kube-proxy --cleanup || true
    fi
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system delete ds kube-proxy

    # Install kube-router networking.
    # KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
    KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /vagrant/config/vagrant/kubeadm-kuberouter-all-features.yaml
    # Install wave networking
    # KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

    # save PKI to /vagrant
    mkdir -p -v /vagrant/config/vagrant/kubernetes/pki/etcd/
    cp -fv /etc/kubernetes/pki/ca.crt /vagrant/config/vagrant/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/ca.key /vagrant/config/vagrant/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/sa.key /vagrant/config/vagrant/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/sa.pub /vagrant/config/vagrant/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/front-proxy-ca.crt /vagrant/config/vagrant/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/front-proxy-ca.key /vagrant/config/vagrant/kubernetes/pki/
    cp -fv /etc/kubernetes/pki/etcd/ca.crt /vagrant/config/vagrant/kubernetes/pki/etcd/
    cp -fv /etc/kubernetes/pki/etcd/ca.key /vagrant/config/vagrant/kubernetes/pki/etcd/
    cp -fv /etc/kubernetes/admin.conf /vagrant/config/vagrant/kubernetes/

    # Wait all components will up
    while [[ "6" > "$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system get pods | grep -E 'router|etcd|coredns|apiserver|controller|scheduler' | grep -i running | wc -l )" ]]; do
        echo "All Kubernetes pods is not yet ready"
        sleep 3
    done
    # If you add nodes later you will need to get a new kubeadm token.
    # Just run the following command on k8s-master1 before the vagrant up of a new node.
    KUBEADM_JOIN=$(kubeadm token create --print-join-command)
    # Fucking Vagrant NAT default route ;(
    KUBEADM_JOIN="${KUBEADM_JOIN} -v 3 --ignore-preflight-errors=\"FileAvailable--etc-kubernetes-pki-ca.crt\""
    KUBEADM_JOIN="${KUBEADM_JOIN} --experimental-control-plane"
    if [[ "${USE_DOCKER}" == "False" ]]; then
        KUBEADM_JOIN="${KUBEADM_JOIN} --cri-socket=/var/run/crio/crio.sock"
    fi
    echo $KUBEADM_JOIN > /vagrant/config/vagrant/kube-join.sh

fi

if hostnameMatches node; then
    while [ ! -f /vagrant/config/vagrant/kube-join.sh ]; do
        echo "Kubernetes master is not yet ready"
        sleep 3
    done
    cp -rfv /vagrant/config/vagrant/kubernetes/* /etc/kubernetes/

    echo "Kubernetes master is ready. Proceeding to join the cluster."
    bash -x /vagrant/config/vagrant/kube-join.sh
fi

sleep 10
# KUBECONFIG=/etc/kubernetes/admin.conf kubectl taint nodes --all node-role.kubernetes.io/master- || true
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -o wide --all-namespaces --include-uninitialized
