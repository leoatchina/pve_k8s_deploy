#!/bin/bash
bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

# ================================================
# delete vm
# ================================================
for id in ${ids[@]}; do
    status=$(qm status $id)
    if [[ $status =~ "status" ]] ; then
        read -p "Are you sure you want to delete VM $id? (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            if [[ $status =~ "running" ]];then
                warn "VM $id is running, stopping and destroying..."
                qm stop $id
                sleep 1
            else
                warn "VM $id is stopped, destroying..."
            fi
            qm destroy $id
        else
            echo "Deletion of VM $id canceled."
        fi
    else
        echo "VM $id is not running. Skipping..."
    fi
    sleep 1
done
