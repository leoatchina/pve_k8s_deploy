
# 说明

## 环境
这个项目是在内部的pve系统上，对已经安装的vm进行操作，并进行k8s集群布置的脚本, 典型配置如下

- 宿主机IP: 192.168.2.99
- 操作系统: ubuntu20.04/ubuntu22.04
- DNS: 192.168.1.1


## 注意点
- 在宿主机上按说明进行脚本的执行
- 在各个脚本中, 使用了一定量的shell 脚本的 `搜索`/`替换` 技巧, 请打开对应文件查看
- 不同的子目录为不同的系统环境下的操作说明

# [0.get_keys.sh](./0.get_keys.sh)
这个脚本是进行ssh 互信, 操作逻辑
- 先在各ip上生成相应的`~/.ssh/id_rsa.pub`, 并连同宿主机的`id_rsa.pub`一起生成一个key文件
- 再检查各个ip的`~/.ssh/authorized_keys`,  如上述各机器的key不在其中, 则加入之.
- 执行, 要加上三个参数:ip前三段, 开始ip第四段, 终止ip第四段

> bash ./0.get_keys.sh 192.168.2  150 154

# [1.basic.sh](./1.basic.sh) 
安装通用的软件, 可以使用for循环在各个ip上, 使用ssh并传入脚本进行命令执行.

> for i in $(seq 150 154);do ip=192.168.2.$i;echo "== $ip ==";ssh -o StrictHostKeyChecking=no root@$ip 'bash -s' < 1.basic.sh; done 

# 其他操作
打开相应的目录查看README
