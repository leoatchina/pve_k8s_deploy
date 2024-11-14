# PVE系统k8s集群搭建

## 说明
这个项目是在内部的`pve系统`上，对已经安装的vm虚拟机操作，进行k8s集群布置的脚本, 典型配置如下
- 宿主机IP: 192.168.3.99
- 操作系统: ubuntu22.04
- DNS: 192.168.1.1
- 下面的`vm`指pve里的虚拟机

## 大概流程
- `手动`复制生成base.config, 并且进行相应内容的调整
- 按数字次序依次执行 sh 文件

## [util.sh](./util.sh)
- 这个文件里有除了k8s组网之外，大部分的操作函数, **如果要在其他机器上使用**，请source之

## [base.config.template](./base.config.template)
- 首先要把`base.config.template 复制成 base.config
- 打开base.config, 根据说明进行修改
- 后续的sh脚本会依次根据ids里的内容生成`vm`
  - vm的ip会是 `$ip_segment.$id`, 比如 ip_segment=192.168.1, id=200，最后生成的vm ip就是192.168.1.200
  - 代理部分是给vm的kubelet 和containerd的service等挂上的代理，要预先在局域网内搞好

## [0.delete_vm.sh](./0.delete_vm.sh)
- 根据`base.config`的`ids`内容， 删除对应`vm`
```
bash ./0.delete_vm.sh
```

## [1.create_vm_sshkey.sh](./1.create_vm_sshkey.sh)

- 根据`base.config`的`ids`内容， 先检查对应id的`vm`的是否存在， 如不存在则安装OS(默认ubuntu22.04), 再设置网络
- 在每个`vm`上生成`sshkey`
- 把宿主机的sshkey和上面生成的key都复制到每个机器上(不会重复复制,  以做好ssh互信
```
bash ./1.create_vm_sshkey.sh
```

## [2.install_softwares.sh](./2.install_softwares.sh)
- 在和每台机器上安装基本软件
- 特定版本containerd(根据base.config)
- kubeadm/kubectl/kubelet，设置服务代理，并且pull基础镜像
- 而在`no_ids`里的`vm` 不会安装kubeadm/kubectl/kubelet和pull镜像
```
bash ./2.install_softwares.sh
```
## [3.k8s_pull.sh](./3.k8s_pull.sh)
- 下载相应的镜像
```
bash ./3.k8s_pull.sh
```

## [4.k8s_cluster](./4.k8s_cluster.sh)
进行k8s组网， 其中放在 `no_ids`里的vm不会加入到k8s里. 注意， 默认没有组`cni` 网络。
