#!/bin/bash

# This script initializes a Kubernetes cluster by configuring the kubelet, pulling required container images,
# and initializing the control or worker nodes.

# Configure kubelet with the specified cgroup driver
cat <<EOF > /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
EOF

# Enable and start the kubelet service
systemctl enable kubelet && systemctl start kubelet

# Get the list of required container images for the cluster
images=$(kubeadm config images list)

echo ===== images need =====
for image in $images
do
    echo $image 
done
echo =======================
echo

echo ===== images exist =====
# List the existing Docker images
docker images | awk 'NR>1 {print $1":"$2}'
echo ========================
echo 

kubeadm_file=/tmp/kubeadm.txt
ctrl_ip=192.168.2.100

# Check if any arguments are provided to the script
if [ $# -gt 0 ]; then
    for image in $images; do
        # Check if the image is already pulled on the specified node
        if [ -z `docker images -q $image` ]; then
            echo "Image $image not pulled on $1" 
            docker pull $image
        else
            echo "Image $image already pulled on $1"
        fi
    done

    rm -rf $HOME/.kube && mkdir -p $HOME/.kube

    # Reset the kubelet service if it is active
    if [[ $(systemctl is-active kubelet) = "active" ]]; then
        echo "==  Kubelet service is running. =="
        echo "y" | kubeadm reset --cri-socket unix:///var/run/cri-dockerd.sock
    else
        echo "Kubelet service is not running."
    fi

    if [ "$1" == "$ctrl_ip" ] ; then
        echo ======== ctrl node init =========
        # Initialize the control node
        kubeadm init \
            --apiserver-advertise-address=$ctrl_ip \
            --node-name $(hostname) \
            --kubernetes-version v1.27.7 \
            --service-cidr=10.96.0.0/12 \
            --pod-network-cidr 10.244.0.0/16 \
            --cri-socket unix:///var/run/cri-dockerd.sock | tee $kubeadm_file
    else
        echo ======== work node init =========
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
