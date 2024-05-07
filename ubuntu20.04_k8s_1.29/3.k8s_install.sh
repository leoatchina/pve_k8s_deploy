cat << EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
 
modprobe overlay
modprobe br_netfilter
 
# 设置所需的 sysctl 参数，参数在重新启动后保持不变
cat << EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
 
# 应用 sysctl 参数而不重新启动
sysctl --system
 
# 通过运行以下指令确认 br_netfilter 和 overlay 模块被加载
lsmod | grep br_netfilter
lsmod | grep overlay
 
# 通过运行以下指令确认 net.bridge.bridge-nf-call-iptables、net.bridge.bridge-nf-call-ip6tables 和 net.ipv4.ip_forward 系统变量在你的 sysctl 配置中被设置为 1
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
 
 
# 如果有防火墙需要参考此文档
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/


# 安装 kubelet/kubeadm/kubectl
apt-get autoremove -y
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
 
apt-get update -y
# apt-get remove kubelet kubeadm kubectl -y
apt-get install -y --allow-change-held-packages kubelet=1.29.3-1.1 kubeadm=1.29.3-1.1 kubectl=1.29.3-1.1

# apt-mark hold kubelet kubeadm kubectl  # 固定版本  
