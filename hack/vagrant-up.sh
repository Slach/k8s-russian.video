#!/usr/bin/env bash
set -exuv -o pipefail

HACK_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
export HACK_DIR

vagrant destroy -f || true
rm -rfv ${HACK_DIR}/../config/vagrant/kubernetes/*
vagrant up k8s-master1 --provision
vagrant up k8s-node1 --provision