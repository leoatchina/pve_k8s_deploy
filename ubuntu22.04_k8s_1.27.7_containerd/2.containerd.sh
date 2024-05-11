#!/bin/bash


apt update -y 
apt install -y containerd

mkdir -p /etc/containerd

/usr/bin/containerd config default > /etc/containerd/config.toml


fl="/etc/containerd/config.toml"

sed -i "s#registry.k8s.io/pause:3.8#registry.aliyuncs.com/google_containers/pause:3.9#g" $fl
sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" $fl 

# 修改特定一行的下一行
awk '/\[plugins."io.containerd.grpc.v1.cri".registry\]/{print NR+1}' $fl | xargs -I{} sed -i '{}s#config_path = ""#config_path = "/etc/containerd/certs.d"#' $fl


# 创建镜像加速的目录 
mkdir /etc/containerd/certs.d/docker.io -pv
# 配置加速
cat > /etc/containerd/certs.d/docker.io/hosts.toml << EOF
server = "https://docker.io"
[host."https://b9pmyelo.mirror.aliyuncs.com"]
  capabilities = ["pull", "resolve"]
EOF


systemctl restart containerd
