#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

keys_file="$HOME/.ssh/keys"
cat ~/.ssh/id_rsa.pub > "$keys_file"

# ================================================
# delete vm
# ================================================

for id in ${ids[@]}; do
    # set ip
    ip=$ip_segment.$id

    if qm status $id | grep -q "status: running"; then
        read -p "Are you sure you want to delete VM $id? (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            echo "VM $id is running. Stopping and destroying..."
            qm stop $id
            qm destroy $id
        else
            echo "Deletion of VM $id canceled."
        fi
    else
        echo "VM $id is not running. Skipping..."
    fi
done

# ================================================
# 生成vm
# ================================================
vm_created=0
for id in ${ids[@]}; do
    if [ $id -eq 99 ]; then
        continue
    fi
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
    vm_created=1
    # configure_network $id $ip_segment $netmask $nameserver $searchdomain
    configure_network $id
    qm start $id
done

# ================================================
# 生成每个机器的sshkey
# ================================================
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
    ssh -o StrictHostKeyChecking=accept-new root@$ip cat ~/.ssh/id_rsa.pub >> "$keys_file"


    # 110 之前的机器，都不允许 ssh password
    if [ $id -gt 110 ] ; then
        sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*
        sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
    else
        sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/*
        sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    fi
    systemctl restart sshd
    echo "sshd Done"

done

# ================================================
# 写入key到每个机器
# ================================================
# NOTE: 如果直接在下面循环读入keys_file, 会出现只读一行的情况
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
done
