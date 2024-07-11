# PVE系统k8s集群搭建

## 说明
这个项目是在内部的`pve系统`上，对已经安装的vm虚拟机操作，进行k8s集群布置的脚本, 典型配置如下
- 宿主机IP: 192.168.3.99
- 操作系统: ubuntu22.04
- DNS: 192.168.1.1
- 下面的`vm`指pve里的虚拟机

## 大概流程
- 根据实际情况，复制生成base.config, 并且进行相应内容的调整
- 按数字次序依次执行 sh 文件

## [base.config.template](./base.config.template)
- 首先要把`base.config.template 复制成 base.config 
- 打开base.config, 根据说明进行修改
- 后续的sh脚本会依次根据ids里的内容生成vm
  - vm的ip会是 $ip_segment.$id, 比如 ip_segment=192.168.1, id=200，最后生成的vm ip就是192.168.1.200
  - 代理部分是给vm的kubelet 和containerd的service等挂上的代理，要预先在局域网内搞好

## [0.delete_vm.sh](./0.delete_vm.sh)
- 根据`base.config`的`ids`内容， 删除对应`vm`

## [1.create_vm_sshkey.sh](./1.create_vm_sshkey.sh)
进行生成sshkey， ssh互信的操作
  首先根据`base.config`的`ids`内容， 先检查对应id的`vm`的是否存在， 如不存在则安装OS(默认ubuntu22.04), 再设置网络
- 在每个`vm`上生成`sshkey`
 [0.delete_vm.sh](./0.delete_vm.sh)
- 根据`base.config`的`ids`内容， 删除对应`vm`

## [1.create_vm_sshkey.sh](./1.create_vm_sshkey.sh)
进行生成sshkey， ssh互信的操作
  首先根据`base.config`的`ids`内容， 先检查对应id的`vm`的是否存在， 如不存在则安装OS(默认ubuntu22.04), 再设置网络
- 在每个`vm`上生成`sshkey`
- 把宿主机的sshkey和上面生成的key都复制到每个机器上(不会重复复制,  以做好ssh互信

## [2.install_softwares.sh](./2.install_softwares.sh)
在和每台机器上安装基本软件，特定版本containerd(根据base.config)，kubeadm/kubectl/kubelet，设置服务代理，并且pull基础镜像， 而在`no_ids`里的vm 不会 安装kubeadm/kubectl/kubelet和pull镜像

## [3.k8s_cluster.sh](./3.k8s_cluster.sh)
进行k8s组网， 其中放在 `no_ids`里的vm不会加入到k8s集群里
