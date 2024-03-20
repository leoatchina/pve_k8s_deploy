#!/bin/bash

for image in $(kubeadm config images list); do
    if docker history $image > /dev/null 2>&1; then
        echo "Image $image is not pulled"
        kubeadm config images pull
        break
    else
        echo "Image $image is pulled"
    fi
done

kubeadm_file=/tmp/kubeadm.txt 
ctrl_ip=192.168.1.100

if [ $# -gt 0 ]; then
    echo "y" | kubeadm reset
    rm -rf $HOME/.kube && mkdir -p $HOME/.kube
    if [ "$1" == "$ctrl_ip" ] ; then
        kubeadm init --control-plane-endpoint=$ctrl_ip --node-name $(hostname) --pod-network-cidr=10.244.0.0/16 | tee $kubeadm_file
    else
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:$kubeadm_file /tmp
    fi
    token=$(grep 'kubeadm join' $kubeadm_file | sed -n -e 's/^.*--token \(\S*\).*$/\1/p' | tail -1)
    discovery_token_ca_cert_hash=$(grep 'discovery\-token\-ca\-cert\-hash' $kubeadm_file | sed -n -e 's/^.*--discovery-token-ca-cert-hash \(\S*\).*$/\1/p' | tail -1)
    if [ "$1" == "$ctrl_ip" ] ; then
        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
    else
        rm $kubeadm_file
        cmd="kubeadm join $ctrl_ip:6443 --token $token --discovery-token-ca-cert-hash $discovery_token_ca_cert_hash"
        $cmd
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:/etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
    fi
fi
