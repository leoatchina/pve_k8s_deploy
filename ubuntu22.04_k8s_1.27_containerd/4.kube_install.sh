#!/bin/bash

# This script installs and configures Kubernetes components on Ubuntu 22.04.

# Load required kernel modules
cat << EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set necessary sysctl parameters to persist after reboot
cat << EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters without rebooting
sysctl --system

# Confirm that the overlay and br_netfilter modules are loaded
lsmod | grep overlay
lsmod | grep br_netfilter

# Confirm that the sysctl variables are set to 1
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# If you have a firewall, refer to the documentation for additional configuration
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/

# Install kubelet, kubeadm, and kubectl
apt-get autoremove -y
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.27/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.27/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl

# Restart kubelet service
systemctl restart kubelet
