# PVE系统k8s集群搭建

## 说明
这个项目是在内部的`pve系统`上，对已经安装的vm虚拟机操作，进行k8s集群布置的脚本, 典型配置如下
- 宿主机IP: 192.168.3.99
- 操作系统: ubuntu22.04
- DNS: 192.168.3.1
- 下面的`vm`指pve里的虚拟机

## [util.sh](./util.sh)
- 这个文件里有除了k8s组网之外，大部分的操作函数, **如果要在其他机器上使用**，请source之

## [base.config.template](./base.config.template)
- 首先要把`base.config.template 复制成 base.config
- 打开base.config, 根据说明进行修改
- 后续的sh脚本会依次根据ids里的内容生成`vm`
  - vm的ip会是 `$ip_segment.$id`, 比如 ip_segment=192.168.1, id=200，最后生成的vm ip就是192.168.1.200
  - 代理部分是给vm的kubelet 和containerd的service等挂上的代理，要预先在局域网内搞好

## 流程
- `手动`复制生成base.config, 并且进行相应内容的调整
- 按数字次序依次执行 sh 文件
- **注意** 直接依次运行脚本文件即可

### [0.delete_vm.sh](./0.delete_vm.sh)
- 根据`base.config`的`ids`内容， 删除对应`vm`
```
bash ./0.delete_vm.sh
```

### [1.create_vm_sshkey.sh](./1.create_vm_sshkey.sh)
- 根据`base.config`的`ids`内容， 先检查对应id的`vm`的是否存在， 如不存在则安装OS(默认ubuntu22.04), 再设置网络
- 在每个`vm`上生成`sshkey`
- 把宿主机的sshkey和上面生成的key都复制到每个机器上(不会重复复制,  以做好ssh互信
```
bash ./1.create_vm_sshkey.sh
```

### [2.install_softwares.sh](./2.install_softwares.sh)
- 在和每台机器上安装基本软件
- 特定版本containerd(根据base.config)
- kubeadm/kubectl/kubelet，设置服务代理，并且pull基础镜像
- 而在`no_ids`里的`vm` 不会安装kubeadm/kubectl/kubelet和pull镜像
```
bash ./2.install_softwares.sh
```
### [3.k8s_pull.sh](./3.k8s_pull.sh)
- 下载相应的镜像
```
bash ./3.k8s_pull.sh
```

### [4.k8s_cluster](./4.k8s_cluster.sh)
进行k8s组网， 其中放在 `no_ids`里的vm不会加入到k8s里. 注意， 默认没有组`cni` 网络。

**脚本说明：**
- 在控制节点上，通过 `kubeadm init` 初始化 Kubernetes 集群，并自动配置 kubeconfig。
- 在工作节点上，通过 `kubeadm join` 加入集群，同时清除旧的 Kubernetes 配置。
- 脚本在各节点上统一清理网络及集群状态，最后在控制节点上部署 Calico CNI 插件（支持 Tailscale 配置）。

#### SSH 相关文件说明
- **ssh_config**  
  - 用途：提供统一的 SSH 客户端连接配置，包括默认的主机、端口、用户名等信息，确保每次 SSH 连接符合预期设置。  
  - 用法：建议根据实际情况，将其内容合并到各机器的 `~/.ssh/config` 中。

- **authorized_keys**  
  - 用途：存储允许 SSH 免密登录的公钥。完成各机器 SSH 密钥配置后，确保各虚拟机的 `authorized_keys` 包含了相应公钥。  
  - 用法：在完成 SSH 互信设置之后，手动或自动将主机和虚拟机的公钥追加到该文件中。

- **ssh_keygen.sh**  
  - 用途：自动化生成 SSH 密钥对的脚本，便于用户快速生成公钥和私钥。  
  - 用法：直接运行该脚本，即可在默认路径生成密钥对，或可根据实际需求调整脚本参数。

- **ssh_copy_id.sh**  
  - 用途：自动化将宿主机 SSH 公钥复制到目标虚拟机，实现免密登录。  
  - 用法：执行此脚本后，系统会依次将宿主机的公钥分发到各个配置好的虚拟机中，确保 SSH 连接免密认证。

### util.sh 函数说明

以下列出了 `util.sh` 文件中主要函数的作用：

- **get_localip**  
  获取当前机器的 IP 地址。该函数调用 `ip addr` 命令，并过滤出与配置文件中 `ip_segment` 匹配的全局 IP 地址。

- **error**  
  使用红色文本在终端输出错误信息，便于标识执行过程中出现的问题。

- **info**  
  使用绿色文本在终端输出提示信息，标识正常的操作状态。

- **warn**  
  使用黄色文本在终端输出警告信息，提醒用户注意潜在风险。

- **configure_network**  
  为指定的虚拟机配置网络参数，包括设置网关、IP 地址（构造规则为 `$ip_segment.$id`）、子网掩码、DNS及搜索域，同时设定 root 用户密码和 SSH 密钥，确保虚拟机具备正确的网络连接与安全设置。

- **create_vm**  
  基于给定的虚拟机 ID（及可选的镜像路径）创建新虚拟机。该函数设置虚拟机的名称、导入磁盘镜像，配置内存、CPU、网络、主机类型、存储设备、启动顺序等参数，并根据 ID 设置不同的磁盘大小。

- **set_pci**  
  为指定虚拟机绑定 PCI 直通设备，使用 `qm set` 命令将指定的 PCI 设备分配给虚拟机，通常用于 GPU 或其它硬件加速卡的直通。

- **sshd_config**  
  修改 SSH 服务的配置文件 `/etc/ssh/sshd_config`，启用 root 登录、启用公钥验证及密码认证，同时清空 `/etc/ssh/sshd_config.d/` 下的扩展配置并重启 SSH 服务。该操作仅在虚拟机 ID 大于 110 时执行，用于确保 SSH 服务配置符合预期。

- **install_softwares**  
  在虚拟机上进行一系列系统配置和软件安装操作。主要包括：  
  - 关闭 swap 并修改 `/etc/fstab`  
  - 设置时区与创建必要的文件夹（例如 `/data/nfs`）  
  - 修改 APT 源为阿里云镜像  
  - 安装各类开发工具、编辑器（vim、tmux）以及其他常用软件  
  - 克隆或更新 `leovim` 与 `fzf` 工具仓库

- **install_containerd**  
  安装 containerd 并生成默认配置文件。之后修改配置文件，将 pause 镜像替换为阿里云镜像，并启用 systemd cgroup 支持，以满足 Kubernetes 容器运行时的要求。

- **install_docker**  
  简单地通过 apt 安装 docker.io，提供 Docker 引擎支持。

- **install_k8s**  
  部署 Kubernetes 相关组件。步骤包括：  
  - 加载内核模块 `overlay` 和 `br_netfilter`  
  - 设置必要的 sysctl 参数  
  - 配置 Kubernetes APT 仓库（使用阿里云的镜像源）  
  - 安装 kubelet、kubeadm 与 kubectl

- **set_proxy**  
  配置指定系统服务配置文件中的代理环境变量（HTTP_PROXY、HTTPS_PROXY、NO_PROXY）。通过检查并添加或修改 `[Service]` 部分中的相应配置，之后重新加载 systemd 配置并重启该服务，以使代理设置生效。

- **d2c**  
  实现 Docker 镜像转换导入功能。该函数先使用 `docker pull` 拉取指定镜像，然后通过 `docker save` 和 `ctr images import` 的组合命令将镜像导入到 containerd 中，默认使用命名空间 `k8s.io`。

- **pull_image**  
  使用 `kubeadm config images list` 获取 Kubernetes 所需的镜像列表，遍历检查每个镜像是否已存在于 containerd 中；若未存在则调用 `d2c` 进行镜像拉取并导入。包含重试机制（最多重试 3 次），可确保镜像成功导入，并最终将 containerd 的 runtime endpoint 设置为 `/var/run/containerd/containerd.sock`。