#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh


for id in ${ids[@]}; do
    ip=$ip_segment.$id

    info "====== K8s pull on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f pull_image d2c); pull_image "
done
