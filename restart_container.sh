#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

for id in ${ids[@]}; do
    ip=$ip_segment.$id

    error "==== restart container related services on $ip ===="
    sleep 2
    ssh -o StrictHostKeyChecking=no root@$ip "systemctl restart docker"
    ssh -o StrictHostKeyChecking=no root@$ip "systemctl restart containerd"
    ssh -o StrictHostKeyChecking=no root@$ip "systemctl restart kubelet"
done
