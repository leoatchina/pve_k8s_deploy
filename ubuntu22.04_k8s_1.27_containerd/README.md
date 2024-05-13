# 说明
在ubuntu22.04 系统上进行k8s集群的搭建, 使用是containerd, 不过也仍然安装docker 


# [2.containerd_docker.sh](./2.containerd_docker.sh)
- 安装containerd和docker,并且使用国内源进行加速
- `containerd` 和 `docker` 在同一个机器上可以共存, 安装后者只是为了某些操作比较方便, 并不直接起作用
- 使用了 `sed`, `awk` 命令进行了特定字符的`搜索`/`定位`/`替换`, 还使用了`cat`,`tee`等命令进行配置文件的布置, 请打开文件进行查看, 主要集中在15-25行


> for i in $(seq 150 154);do ip=192.168.2.$i;echo "== $ip ==";ssh -o StrictHostKeyChecking=no root@$ip 'bash -s' < 2.containerd_docker.sh; done 


# [3.kube_install.sh](./3.kube_install.sh)
- 安装kubelet

> for i in $(seq 150 154);do ip=192.168.2.$i;echo "== $ip ==";ssh -o StrictHostKeyChecking=no root@$ip 'bash -s' < 3.kube_install.sh; done 


# [4.k8s_pull.sh](./4.k8s_pull.sh)
- 利用`ctr`命令(安装containerd时一起安装) pull 相应的镜像
- 先要`kubeadm` 命令得到需要的image
- 利用`ctr image list` 命令得到已有的image
- 两相比较, 下载缺少的image

> for i in $(seq 150 154);do ip=192.168.2.$i;echo "== $ip ==";ssh -o StrictHostKeyChecking=no root@$ip 'bash -s' < 4.k8s_pull.sh; done 


# [5.k8s_cluster.sh](./5.k8s_cluster.sh)
- 布置k8s集群
- 此脚本要传入两个参数: 对应IP, 控制IP 
- 根据ip的不同进行不同的操作
    - 如果是控制ip, 进行集群控制平面的初始化, 并且把此过程中的输入文件保存到一个文件中
    - 如果是其他ip, 从控制ip上复制此文件, 并从中提取对应的`key` 和 `sha256`, 并加入到集群中

> for i in $(seq 150 154);do ip=192.168.2.$i;echo "== $ip ==";ssh -o StrictHostKeyChecking=no root@$ip 'bash -s' < 5.k8s_cluster.sh $ip 192.168.2.150 ; done 


