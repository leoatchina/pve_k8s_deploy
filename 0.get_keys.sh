#!/bin/bash

if [ $# -ne 3 ]; then    
    echo "Error: Exactly 3 arguments are required."
    exit 1
fi
echo "Proceeding with the script..."


net=$1
start=$2
end=$3


#
keys_file="$HOME/.ssh/keys"
cat ~/.ssh/id_rsa.pub > "$keys_file" 

for i in $(seq $start $end); do
    ip="$net.$i"
    # 使用SSH连接到主机并获取公钥
    echo "====== Processing key generate on $ip ==============="
    ssh-keygen -f "/root/.ssh/known_hosts" -R "$ip"
    # ssh root@$ip 
    ssh -o StrictHostKeyChecking=accept-new root@$ip 'echo "y" | ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""'
    ssh -o StrictHostKeyChecking=accept-new root@$ip cat ~/.ssh/id_rsa.pub >> "$keys_file"
done

echo 

# NOTE: 如果直接在下面循环读入keys_file, 会出现只读一行的情况
mapfile -t keys < <(awk '{print $0}' "$keys_file")
for i in $(seq $start $end); do
    if [ $i -eq 99 ]; then
        continue
    fi

    ip="$net.$i"

    echo "====== Processing key add on $ip ==============="

    for key in "${keys[@]}"; do
        # Check if the key already exists in the authorized_keys file
        key2=$(echo $key | cut -d' ' -f2)
        # NOTE: 为了解决空格的问题, 把第二个字符串提取出来, ONLY比较这个key2
        if ssh -o StrictHostKeyChecking=accept-new root@$ip "grep -qF '$key2' ~/.ssh/authorized_keys"; then
            echo "Key already exists in authorized_keys on $ip"
        else
            echo "Adding key to authorized_keys on $ip"
            echo "$key" | ssh -o StrictHostKeyChecking=accept-new root@$ip "cat >> ~/.ssh/authorized_keys"
        fi
        echo
    done 
done
