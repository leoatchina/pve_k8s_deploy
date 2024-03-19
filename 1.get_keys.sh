#!/bin/bash


ips=("192.168.1."{99..105})
keys_file="$HOME/.ssh/keys"

for i in {99..105}; do
    ip="192.168.1.$i"
    echo "Getting SSH key for $ip"
    # 使用SSH连接到主机并获取公钥
    if [[ $i -eq 99 ]]; then
        ssh -o StrictHostKeyChecking=no root@$ip cat ~/.ssh/id_rsa.pub > "$keys_file" 
    else
        ssh -o StrictHostKeyChecking=no root@$ip cat ~/.ssh/id_rsa.pub >> "$keys_file"
    fi
done

for ip in "${ips[@]}"; do
    echo "Processing $ip"
    # Ensure .ssh directory exists
    ssh root@$ip "mkdir -p ~/.ssh"
    # Loop over each key in the keys file
    while IFS= read -r key; do
        # Check if the key already exists in the authorized_keys file
        if ssh root@$ip "grep -qF '$key' ~/.ssh/authorized_keys"; then
            echo "Key already exists in authorized_keys"
        else
            echo "Adding key to authorized_keys"
            echo "$key" | ssh root@$ip "cat >> ~/.ssh/authorized_keys"
        fi
    done < "$keys_file"
done
