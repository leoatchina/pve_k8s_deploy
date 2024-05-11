#!/bin/bash

rm /tmp/kube-flannel.yml
cd /tmp && wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
sed -i "s#docker.io#docker.m.daocloud.io#g" /tmp/kube-flannel.yml
kubectl apply -f /tmp/kube-flannel.yml
