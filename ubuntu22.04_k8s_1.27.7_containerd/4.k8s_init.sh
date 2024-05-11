#!/bin/bash

# This script initializes a Kubernetes cluster by configuring the kubelet, pulling required container images,
# and initializing the control or worker nodes.


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
echo

echo ===== images exist =====
# List the existing images
ctr image list | awk 'NR>1 {print $1":"$2}'
echo ========================
echo

max_retries=3
for image in $images; do
    retry=0
    # Check if the image is already pulled on the specified node
    echo "==== pull $image ===="

    while [ $retry -lt $max_retries ]
    do
        if ctr image pull "$image"; then
            echo "image pull succeeded."
            break
        else
            retry=$((retry+1))
            echo "image pull failed, retrying ($retry/$max_retries)..."
            sleep $retry
        fi
    done

    if [ $retry -ge $max_retries ]; then
        echo "image pull failed after $max_retries attempts."
        exit 1
    fi
done

crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
