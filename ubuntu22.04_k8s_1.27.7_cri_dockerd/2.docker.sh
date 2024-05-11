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

# 下载安装最新版的cri-dockerd
# wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.13/cri-dockerd-0.3.13.amd64.tgz
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.13/cri-dockerd_0.3.13.3-0.ubuntu-jammy_amd64.deb -O /tmp/cri-dockerd.deb
dpkg -i /tmp/cri-dockerd.deb
sed -i 's#^ExecStart=.*$#ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.9#' /usr/lib/systemd/system/cri-docker.service
systemctl start cri-docker && systemctl status cri-docker


reboot
