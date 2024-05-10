#!/bin/bash


apt -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
apt update -y

# containerd 是k8s 的容器运行时, 要删除掉,换成docker-ce
apt remove -y containerd && apt -y autoremove

# 指定了某个版本的docker 
apt -y update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose
# apt -y update && apt install -y docker-ce=5:26.0.0-1 docker-ce-cli containerd.io docker-buildx-plugin docker-compose
# apt -y update && apt install -y docker-ce=5:26 docker-ce-cli containerd.io docker-buildx-plugin docker-compose

cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
   "registry-mirrors": [
        "https://rsbud4vc.mirror.aliyuncs.com",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://dockerhub.azk8s.cn",
        "http://hub-mirror.c.163.com"
    ]
}
EOF

systemctl enable docker && systemctl start docker
reboot
