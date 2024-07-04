#!/bin/bash

# Update the package list
apt update -y && apt upgrade -y && apt autoremove -y

# docker
apt -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
apt update -y

apt -y update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose

mkdir -p /etc/docker

cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
   "registry-mirrors": [
        "https://registry.docker-cn.com",
        "https://dockerproxy.com",
        "https://docker.m.daocloud.io",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://dockerhub.azk8s.cn",
        "http://hub-mirror.c.163.com"
    ]
}
EOF
systemctl restart docker
