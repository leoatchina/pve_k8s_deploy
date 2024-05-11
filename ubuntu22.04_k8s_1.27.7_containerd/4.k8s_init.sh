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
# List the existing Docker images
docker images | awk 'NR>1 {print $1":"$2}'
echo ========================

max_retries=3
for image in $images; do
    retry=0
    # Check if the image is already pulled on the specified node
    if [ -z `docker images -q $image` ]; then
        echo "==== Image $image not pulled on $ip ===="
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
        echo "==== Image $image already pulled on $ip ===="
    fi
done


crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
