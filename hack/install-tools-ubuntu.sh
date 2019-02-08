#!/usr/bin/env bash
set -exuv -o pipefail

sudo apt-get install -y apt-transport-https
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt-add-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y kubectl
sudo apt-get install -y docker-ce docker-ce-cli
rm -rf /tmp/minikube* /tmp/docker*kvm2
curl -fsSL -o /tmp/minikube_0.33-1.deb https://github.com/kubernetes/minikube/releases/download/v0.33.1/minikube_0.33-1.deb
sudo dpkg -i /tmp/minikube_0.33-1.deb
sudo apt install libvirt-clients libvirt-daemon-system qemu-kvm
sudo usermod -a -G libvirt $(whoami)
curl -fsSL -o /tmp/docker-machine-driver-kvm2 https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2
sudo install /tmp/docker-machine-driver-kvm2 /usr/local/bin/