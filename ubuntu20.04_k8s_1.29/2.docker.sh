#!/bin/bash

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys  B53DC80D13EDEF05

curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -

add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# containerd 是k8s 的容器运行时, 要删除掉,换成docker-ce
apt remove -y containerd && apt -y autoremove
# 指定了某个版本的docker 
apt -y update && apt install -y docker-ce=5:26.0.0-1~ubuntu.22.04~jammy docker-ce-cli containerd.io docker-buildx-plugin docker-compose

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


systemctl enable docker && systemctl start docker && systemctl status docker && docker info | grep systemd

# 下载安装最新版的cri-dockerd
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.13/cri-dockerd-0.3.13.amd64.tgz
tar xf cri-dockerd-0.3.13.amd64.tgz
mv cri-dockerd/cri-dockerd  /usr/bin/
rm -rf cri-dockerd cri-dockerd-0.3.13.amd64.tgz

# 配置启动项
cat > /etc/systemd/system/cri-docker.service<<EOF
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket
[Service]
Type=notify
# ExecStart=/usr/bin/cri-dockerd --container-runtime-endpoint fd://
# 指定用作 Pod 的基础容器的容器镜像（“pause 镜像”）
ExecStart=/usr/bin/cri-dockerd --pod-infra-container-image=registry.k8s.io/pause:3.9 --container-runtime-endpoint fd://
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/cri-docker.socket <<EOF
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service
[Socket]
ListenStream=%t/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker
[Install]
WantedBy=sockets.target
EOF

systemctl daemon-reload
systemctl enable cri-docker && systemctl start cri-docker && systemctl status cri-docker
