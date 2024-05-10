#!/bin/bash


apt update -y 
apt install -y containerd

mkdir -p /etc/containerd

/usr/bin/containerd config default > /etc/containerd/config.toml

sed -i "s#registry.k8s.io/pause#registry.aliyuncs.com/google_containers/pause#g" /etc/containerd/config.toml

crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock

systemctl restart containerd
