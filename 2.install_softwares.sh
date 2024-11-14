#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh


if [[ -n $http_proxy && $http_proxy =~ [^[:space:]] ]] && [[ -n $https_proxy && $https_proxy =~ [^[:space:]] ]] && [[ -n $no_proxy && $no_proxy =~ [^[:space:]] ]]; then
    proxy_exist=1
else
    proxy_exist=0
fi


for id in ${ids[@]}; do
    ip=$ip_segment.$id

    warn "============================================="
    warn "====== Installing on $ip ======"
    warn "============================================="

    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_softwares); install_softwares"

    info "====== Installing containerd on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_containerd); install_containerd"
    if [ $proxy_exist > 0 ]; then
        warn "====== Set containerd proxy on $ip ======"
        ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f set_proxy); set_proxy /usr/lib/systemd/system/containerd.service $http_proxy $https_proxy $no_proxy"
    fi

    info "====== Installing docker on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_docker); install_docker"
    if [ $proxy_exist > 0 ]; then
        warn "====== Set docker proxy on $ip ======"
        ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f set_proxy); set_proxy /usr/lib/systemd/system/docker.service $http_proxy $https_proxy $no_proxy"
    fi

    if [[ "${nok8s_ids[@]}" =~ "${id}" ]]; then
        error ============ not install k8s on $ip ===================
    else
        warn "====== Installing k8s on $ip ======"
        ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_k8s); install_k8s $k8s_version"

        if [ $proxy_exist > 0 ]; then
            info "====== Set kubelet proxy on $ip ======"
            ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f set_proxy); set_proxy /usr/lib/systemd/system/kubelet.service $http_proxy $https_proxy $no_proxy"
        fi

    fi
    sleep 5
done
