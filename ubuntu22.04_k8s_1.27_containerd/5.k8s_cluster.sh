#!/bin/bash


if [ $# -eq 2 ]; then
    ip=$1
    ctrl_ip=$2

    kubeadm_file=/tmp/kubeadm.txt
    version=$(kubelet --version | awk '{print $2}')

    # Reset the kubelet service if it is active
    rm -rf $HOME/.kube && mkdir -p $HOME/.kube
    if [[ $(systemctl is-active kubelet) =~ ^activ ]]; then
        echo "== Kubelet service is running =="
        echo "y" | kubeadm reset
    else
        echo "== Kubelet service is not running =="
    fi


    mkdir -p /etc/cni/net.d
    if [ "$ip" == "$ctrl_ip" ] ; then
        echo ======== ctrl node init =========
        # Initialize the control node
        rm -rf /etc/cni/net.d/*
        rm -rf /etc/kubernetes/manifests/*
        kubeadm init \
            --apiserver-advertise-address=$ctrl_ip \
            --node-name=$(hostname) \
            --kubernetes-version=$version \
            --service-cidr=10.96.0.0/12 \
            --pod-network-cidr=10.244.0.0/16 | tee $kubeadm_file
        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
        # flannel net Initialize
        rm /tmp/kube-flannel.yml
        cd /tmp && wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        sed -i "s#docker.io#docker.m.daocloud.io#g" /tmp/kube-flannel.yml
        kubectl apply -f /tmp/kube-flannel.yml
    else
        echo ======== work node join =========
        # Initialize a worker node
        ssh-keygen -f "/root/.ssh/known_hosts" -R $ctrl_ip
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:$kubeadm_file $kubeadm_file 
        # Join the worker node to the control node
        token=$(grep 'kubeadm join' $kubeadm_file | sed -n -e 's/^.*--token \(\S*\).*$/\1/p' | tail -1)
        token_hash=$(grep 'discovery\-token\-ca\-cert\-hash' $kubeadm_file | sed -n -e 's/^.*--discovery-token-ca-cert-hash \(\S*\).*$/\1/p' | tail -1)
        rm $kubeadm_file
        kubeadm join $ctrl_ip:6443 --token $token --discovery-token-ca-cert-hash $token_hash
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:/etc/kubernetes/admin.conf $HOME/.kube/config
    fi

    sed -i 's#--network-plugin=cni##' /var/lib/kubelet/kubeadm-flags.env

    cat > /etc/cni/net.d/10-flannel.conf <<EOF
{
  "name": "cbr0",
  "cniVersion": "0.2.0",
  "type": "flannel",
  "delegate": {
    "isDefaultGateway": true
  }
} 
EOF

    systemctl restart kubelet

else
    echo "you should offer ip && ctrl_ip."
fi

