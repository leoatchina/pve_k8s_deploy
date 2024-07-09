# PVE系统k8s集群搭建

## 说明
这个项目是在内部的`pve系统`上，对已经安装的vm虚拟机操作，进行k8s集群布置的脚本, 典型配置如下
- 宿主机IP: 192.168.2.99
- 操作系统: ubuntu20.04/ubuntu22.04
- DNS: 192.168.1.1
- 下面的`vm`指pve里的虚拟机

## 大概流程
- 在宿主机上按说明进行脚本的执行
- 按数字次序依次执行
- 在各个脚本中, 使用了一定量的shell 脚本的 `搜索`/`替换` 技巧, 请打开对应文件查看

## [base.config.template](./base.config.template)
- 首先要把base.config.template复制成base.config
- 打开base.config, 根据说明进行修改
- 会依次根据ids里的内容生成vm
  - vm的ip会是 $ip_segment.$id, 比如 ip_segment=192.168.1 , id=200，最后生成的vm ip就是192.168.1.200
  - 代理部分是给vm的kubelet 和containerd的service等挂上的代理，要预先在局域网内搞好
## [0.delete_vm.sh](./0.delete_vm.sh)
- 根据`base.config`的`ids`内容， 删除对应`vm`

## [1.create_vm_sshkey.sh](./1.create_vm_sshkey.sh)
进行生成， ssh互信的操作

- 首先根据`base.config`的`ids`内容， 先检查对应id的`vm`的是否存在， 如不存在则生成(默认ubuntu22.04), 再设置网络
- 在每个`vm`上生成`sshkey`
- 把宿主机的sshkey和上面生成的key都复制到每个机器上，做好ssh互信

## [2.install_softwares.sh](./2.install_softwares.sh)
在和每台机器上安装基本软件、特定版本containerd(根据base.config)、kubeadm/kubectl/kubelet、设置服务代理、并且pull基础镜像

## [3.k8s_cluster.sh](./3.k8s_cluster.sh)
进行k8s组网， 其中放在 `no_ids`里的vm不会加入到k8s集群里