#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

restart_container () {
    [ -f /bin/docker ] && systemctl restart docker
    [ -f /bin/containerd ] && systemctl restart containerd 
    [ -f /bin/kubelet ] && systemctl restart kubelet 
}

for id in ${ids[@]}; do
    ip=$ip_segment.$id
    error "==== restart container related services on $ip ===="
    sleep 2
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f restart_container); restart_container "
done
