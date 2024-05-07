#!/bin/bash

# This script initializes a Kubernetes cluster by configuring the kubelet, pulling required container images,
# and initializing the control or worker nodes.

# echo 'KUBELET_EXTRA_ARGS="--container-runtime-endpoint=unix:///var/run/cri-dockerd.sock --fail-swap-on=false --cgroup-driver=systemd"' > /etc/default/kubelet
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' > /etc/default/kubelet

# Configure kubelet with the specified cgroup driver
# echo 'KUBELET_EXTRA_ARGS="' >> /etc/sysconfig/kubelet

# Enable and start the kubelet service
# systemctl enable kubelet && systemctl restart kubelet && systemctl status kubelet



# Get the list of required container images for the cluster
images=$(kubeadm config images list)

echo ===== images need =====
for image in $images
do
    echo $image
done
echo ===== images exist =====
# List the existing Docker images
docker images | awk 'NR>1 {print $1":"$2}'
echo ========================
echo

kubeadm_file=/tmp/kubeadm.txt
ctrl_ip=192.168.2.100


# Check if any arguments are provided to the script
if [ $# -gt 0 ]; then
    if [ $# -gt 1 ]; then
        ctrl_ip=$2
    else
        ctrl_ip=192.168.2.100
    fi
    max_retries=3
    for image in $images; do
        retry=0
        # Check if the image is already pulled on the specified node
        if [ -z `docker images -q $image` ]; then
            echo "==== Image $image not pulled on $1 ===="
            while [ $retry -lt $max_retries ]
            do
                if docker pull $image; then
                    echo "Docker pull succeeded."
                    break
                else
                    retry=$((retry+1))
                    echo "Docker pull failed, retrying ($retry/$max_retries)..."
                    sleep $retry
                fi
            done

            if [ $retry -ge $max_retries ]; then
                echo "Docker pull failed after $max_retries attempts."
                exit 1
            fi
        else
            echo "==== Image $image already pulled on $1 ===="
        fi
    done

    rm -rf $HOME/.kube && mkdir -p $HOME/.kube
    echo

    # Reset the kubelet service if it is active
    if [[ $(systemctl is-active kubelet) =~ ^activ ]]; then
        echo "== Kubelet service is running =="
        echo "y" | kubeadm reset --cri-socket unix:///var/run/cri-dockerd.sock
    else
        echo "== Kubelet service is not running =="
    fi

    if [ "$1" == "$ctrl_ip" ] ; then
        echo ======== ctrl node init =========
        # Initialize the control node
        rm -r /etc/cni/net.d/*
        kubeadm init \
            --apiserver-advertise-address=$ctrl_ip \
            --node-name $(hostname) \
            --kubernetes-version v1.27.7 \
            --service-cidr=10.96.0.0/12 \
            --pod-network-cidr 10.244.0.0/16 \
            --cri-socket unix:///var/run/cri-dockerd.sock | tee $kubeadm_file
    else
        echo ======== work node join =========
        # Initialize a worker node
        ssh-keygen -f "/root/.ssh/known_hosts" -R $ctrl_ip
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:$kubeadm_file /tmp
    fi

    if [ "$1" == "$ctrl_ip" ] ; then
        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
        # chown $(id -u):$(id -g) $HOME/.kube/config
    else
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
