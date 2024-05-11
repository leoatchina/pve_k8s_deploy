#!/bin/bash

# This script installs and configures containerd, a container runtime, on Ubuntu 22.04.

# Update the package list
apt update -y

# Install containerd
apt install -y containerd

# Create the containerd configuration directory
mkdir -p /etc/containerd

# Generate the default containerd configuration file
/usr/bin/containerd config default > /etc/containerd/config.toml

# Modify the containerd configuration file to use a different container image registry
fl="/etc/containerd/config.toml"
sed -i "s#registry.k8s.io/pause:3.8#registry.aliyuncs.com/google_containers/pause:3.9#g" $fl

# Enable systemd cgroup support in containerd
sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" $fl 

# Modify the configuration file to specify the path for containerd certificates
awk '/\[plugins."io.containerd.grpc.v1.cri".registry\]/{print NR+1}' $fl | xargs -I{} sed -i '{}s#config_path = ""#config_path = "/etc/containerd/certs.d"#' $fl

# Create the directory for image acceleration
mkdir /etc/containerd/certs.d/docker.io -pv

# Configure image acceleration for docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml << EOF
server = "https://docker.io"
[host."https://b9pmyelo.mirror.aliyuncs.com"]
  capabilities = ["pull", "resolve"]
EOF

# Restart containerd to apply the changes
systemctl restart containerd
