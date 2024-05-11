#!/bin/bash


apt update -y 
apt install -y containerd

mkdir -p /etc/containerd

/usr/bin/containerd config default > /etc/containerd/config.toml

sed -i "s#registry.k8s.io/pause:3.8#registry.aliyuncs.com/google_containers/pause:3.9#g" /etc/containerd/config.toml
sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" /etc/containerd/config.toml

systemctl restart containerd

reboot
