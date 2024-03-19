#!/bin/bash

# 遍历IP地址
for i in {99..105}; do
    ip="192.168.2.$i"
    echo "Getting SSH key for $ip"
    # 使用SSH连接到主机并获取公钥
    if [[ $i -eq 99 ]]; then
        ssh -o StrictHostKeyChecking=no root@$ip cat ~/.ssh/id_rsa.pub > ~/.ssh/keys.txt
    else
        ssh -o StrictHostKeyChecking=no root@$ip cat ~/.ssh/id_rsa.pub >> ~/.ssh/keys.txt
    fi
done
