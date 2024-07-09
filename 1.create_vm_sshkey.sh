#!/bin/bash
bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

# ================================================
# 生成vm
# ================================================
for id in ${ids[@]}; do
    if [ $id -eq 99 ]; then
        continue
    fi
    echo
    if qm status $id >/dev/null 2>&1; then
        warn "=== vm $id exists, only set $id's network and password ==="
        qm stop $id
    else
        info "== vm $id not exists, create it ==="
        if [ $# -gt 0 ]; then
            img=$1
            create_vm $id $img
        else
            create_vm $id
        fi
    fi
    # configure_network 
    info "=== vm $id updating network ==="
    configure_network $id
    sleep 4
    info "=== vm $id starting ==="
    qm start $id
done


# NOTE:  must sleep to enable last vm
sleep 10

# ================================================
# 生成每个机器的sshkey
# ================================================
echo 
keys_file="$HOME/.ssh/keys"
cat ~/.ssh/id_rsa.pub > "$keys_file"
for id in ${ids[@]}; do
    if [ $id -eq 99 ]; then
        continue
    fi
    ip="$ip_segment.$id"
    # 使用SSH连接到主机并获取公钥
    info "====== Processing key generate on $ip ==============="
    ssh-keygen -f "/root/.ssh/known_hosts" -R "$ip"
    # ssh root@$ip
    ssh -o StrictHostKeyChecking=accept-new root@$ip '[ ! -f "$HOME/.ssh/id_rsa" ] && echo "y" | ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""'
    sleep 1 
    ssh -o StrictHostKeyChecking=accept-new root@$ip cat ~/.ssh/id_rsa.pub >> "$keys_file"
    sleep 1
done


# ================================================
# 写入key到每个机器
# ================================================
# NOTE: 如果直接在下面循环读入keys_file, 会出现只读一行的情况
echo 
mapfile -t keys < <(awk '{print $0}' "$keys_file")
for id in ${ids[@]}; do
    if [ $id -eq 99 ]; then
        continue
    fi
    ip="$ip_segment.$id"
    info "====== Processing key add on $ip ==============="

    for key in "${keys[@]}"; do
        # Check if the key already exists in the authorized_keys file
        key2=$(echo $key | cut -d' ' -f2)
        node=$(echo $key | cut -d' ' -f3)
        # NOTE: 为了解决空格的问题, 把第二个字符串提取出来, ONLY比较这个key2
        if ssh -o StrictHostKeyChecking=accept-new root@$ip "grep -qF '$key2' ~/.ssh/authorized_keys"; then
            warn "Key of $node already exists in authorized_keys on $ip"
        else
            info "Adding key of $node to authorized_keys on $ip"
            echo "$key" | ssh -o StrictHostKeyChecking=accept-new root@$ip "cat >> ~/.ssh/authorized_keys"
        fi
    done
    sleep 2
done

# ================================================
# sshd_config 
# ================================================
sshd_config () {
    if [ $# -gt 0 ]; then
        id=$1 
    else
        return 
    fi
    sed_replace () {
        fl=$1 
        sed -i 's/^#.*PermitRootLogin.*$/PermitRootLogin yes/' $fl 
        sed -i 's/^#.*PubkeyAuthentication.*$/PubkeyAuthentication yes/' $fl 
        sed -i 's/^#.*PasswordAuthentication.*$/PasswordAuthentication yes/' $fl 
    }
    if [ $id -gt 110 ] ; then
        sed_replace /etc/ssh/sshd_config
        rm /etc/ssh/sshd_config.d/*
        systemctl restart sshd
        echo "sshd Done"
    fi
}

for id in ${ids[@]}; do
    if [ $id -eq 99 ]; then
        continue
    fi
    ip=$ip_segment.$id
    info "====== Set sshd_config on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f sshd_config); sshd_config $id"
done
