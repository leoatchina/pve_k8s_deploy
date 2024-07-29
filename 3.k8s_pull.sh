#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh


d2c (){
    if [[ $# < 1 ]]; then
        echo ====== please input image name =======
        return
    else
        img=$1
        if [[ $# > 1 ]]; then
            ns=$2
        else
            ns=k8s.io
        fi
    fi
    cmd="docker pull $img && docker save $img | ctr -n=$ns images import -"
    echo $cmd
    eval $cmd
}

pull_image () {
    if [ ! -f /usr/bin/kubectl ];then
        echo ============== no kubectl installed ==========
        return
    fi
    images=$(kubeadm config images list)
    echo ===== images need =====
    for image in $images
    do
        echo $image
    done

    echo ===== images exist =====
    ctr -n k8s.io image list | awk 'NR>1 {print $1":"$2}'
    echo ======= pulling images =================

    # 正式pull
    max_retries=3
    for image in $images; do
        retry=0
        # Check if the image is already pulled on the specified node
        if ctr -n k8s.io image list | grep -q "$image"; then
            echo "$image already pulled."
        else
            while [[ $retry -lt $max_retries ]]
            echo "==== pulling $image ===="
            do
                if d2c "$image"; then
                    if [ $retry -eq 0 ]; then
                        echo "$image pull succeeded."
                    else
                        echo "$image pull succeeded after $retry retries."
                    fi
                    break
                else
                    retry=$((retry+1))
                    echo "image pull failed, retrying ($retry/$max_retries)..."
                    sleep $retry
                fi
            done

            if [ $retry -ge $max_retries ]; then
                echo "image pull failed after $max_retries attempts, please check your net, exiting."
                exit 1
            fi
        fi
    done
    crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
}


for id in ${ids[@]}; do
    ip=$ip_segment.$id

    info "====== K8s pull on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f pull_image d2c); pull_image "
done
