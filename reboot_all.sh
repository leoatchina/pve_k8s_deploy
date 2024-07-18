#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

for id in ${ids[@]}; do
    ip=$ip_segment.$id

    error "==== rebooting $ip ===="
    sleep 2
    ssh -o StrictHostKeyChecking=no root@$ip "reboot"
done

