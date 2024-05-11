#!/bin/bash
# Check if any arguments are provided to the script
if [ $# -eq 2 ]; then
    kubeadm_file=/tmp/kubeadm.txt
    ip=$1 
    ctrl_ip=$2

    rm -rf $HOME/.kube && mkdir -p $HOME/.kube
    echo

    # Reset the kubelet service if it is active
    if [[ $(systemctl is-active kubelet) =~ ^activ ]]; then
        echo "== Kubelet service is running =="
        echo "y" | kubeadm reset --cri-socket unix:///var/run/cri-dockerd.sock
    else
        echo "== Kubelet service is not running =="
    fi

    if [ "$ip" == "$ctrl_ip" ] ; then
        echo ======== ctrl node init =========
        # Initialize the control node
        rm -r /etc/cni/net.d/*
        kubeadm init \
            --apiserver-advertise-address=$ctrl_ip \
            --node-name $(hostname) \
            --kubernetes-version v1.27.13 \
            --service-cidr=10.96.0.0/12 \
            --pod-network-cidr 10.244.0.0/16 \
            --cri-socket unix:///var/run/cri-dockerd.sock | tee $kubeadm_file
        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    else
        echo ======== work node join =========
        # Initialize a worker node
        ssh-keygen -f "/root/.ssh/known_hosts" -R $ctrl_ip
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:$kubeadm_file /tmp

        # Join the worker node to the control node
        token=$(grep 'kubeadm join' $kubeadm_file | sed -n -e 's/^.*--token \(\S*\).*$/\1/p' | tail -1)
        discovery_token_ca_cert_hash=$(grep 'discovery\-token\-ca\-cert\-hash' $kubeadm_file | sed -n -e 's/^.*--discovery-token-ca-cert-hash \(\S*\).*$/\1/p' | tail -1)

        rm $kubeadm_file

        cmd="kubeadm join $ctrl_ip:6443 --token $token --discovery-token-ca-cert-hash $discovery_token_ca_cert_hash --cri-socket=unix:///var/run/cri-dockerd.sock"

        $cmd
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:/etc/kubernetes/admin.conf $HOME/.kube/config
        # chown $(id -u):$(id -g) $HOME/.kube/config
    fi
fi

