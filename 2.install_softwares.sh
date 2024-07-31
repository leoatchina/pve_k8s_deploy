#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

# ================================================
# install_softwares
# ================================================
install_softwares() {
    # swap off
    swapoff -a
    sed -ri 's/.*swap.*/#&/' /etc/fstab
    # set time , create dir file maybe needed
    timedatectl set-timezone Asia/Shanghai
    mkdir -p /data/nfs
    # set vimr.local firstly
    cat << EOF | tee ~/.vimrc.local
if has('nvim')
    source ~/.leovim/conf.d/init.vim
endif
EOF

    # set apt sources
    sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
    sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
    # apt install 
    apt update -y
    apt install -y libevent-dev ncurses-dev bison pkg-config build-essential
    apt install -y vim git ripgrep universal-ctags htop zip unzip
    apt install -y apt-transport-https ca-certificates curl software-properties-common
    apt install -y lua5.3 nfs-common net-tools sshfs tcpdump
    apt install -y python3-pip python3-venv && pip install neovim

    # tmux
    [ -f /usr/bin/tmux ] && apt remove -y tmux && rm /usr/bin/tmux
    if [ ! -f /usr/local/bin/tmux ]; then
        [ -f /tmp/tmux-3.4.tar.gz ] && rm /tmp/tmux-3.4.tar.gz
        cd /tmp && wget https://github.com/tmux/tmux/releases/download/3.4/tmux-3.4.tar.gz && \
            tar xvf tmux-3.4.tar.gz && cd tmux-3.4 && ./configure --prefix=/usr/local/bin && make -j 4 && make install
    fi

    # leovim
    mkdir -p ~/.local
    if [ -d ~/.leovim ]; then
        cd ~/.leovim && git pull
    else
        git clone https://gitee.com/leoatchina/leovim.git ~/.leovim
    fi

    if [ -d ~/.local/fzf ]; then
        cd ~/.local/fzf && git pull && ./install --all
    else
        git clone --depth 1 https://github.com/junegunn/fzf ~/.local/fzf && cd ~/.local/fzf && ./install --all
    fi

}

install_containerd() {
    # apt update -y && apt upgrade -y && apt autoremove -y
    apt update -y
    # Install containerd
    apt install -y containerd

    # Create the containerd configuration directory
    rm -rf /etc/containerd && mkdir -p /etc/containerd
    [ -f /etc/containerd/config.toml ] && rm /etc/containerd/config.toml
    containerd config default | tee /etc/containerd/config.toml


    # Modify the containerd configuration file to use a different container image registry
    fl="/etc/containerd/config.toml"
    sed -i "s#registry.k8s.io/pause:3.8#registry.aliyuncs.com/google_containers/pause:3.9#g" $fl

    # Enable systemd cgroup support in containerd
    sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" $fl
}

install_docker() {
    # apt update -y && apt upgrade -y && apt autoremove -y
    apt update -y
    apt install -y docker.io
}


install_k8s() {
    version=$1
    # Load required kernel modules
    cat << EOF | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    # Set necessary sysctl parameters to persist after reboot
    cat << EOF | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF

    # Apply sysctl parameters without rebooting
    sysctl --system

    # Confirm that the overlay and br_netfilter modules are loaded
    lsmod | grep overlay
    lsmod | grep br_netfilter

    # Confirm that the sysctl variables are set to 1
    sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

    # If you have a firewall, refer to the documentation for additional configuration
    # https://kubernetes.io/docs/reference/networking/ports-and-protocols/

    # Install kubelet, kubeadm, and kubectl
    apt-get autoremove -y
    curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/$version/deb/Release.key | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/$version/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
}

# 代理设置
set_proxy () {
    local_echo() {
        echo -e "\033[34m$@\033[0m"
    }
    
    fl=$1
    if [ -f "$fl" ]; then
        local_echo "$fl exists."
    else
        local_echo "$fl does not exist."
        return
    fi

    http_proxy="$2"
    https_proxy="$3"
    no_proxy="$4"
    
    # 检查并添加代理设置
    add_proxy_if_missing() {
        local service_file="$1"
        local setting_name="$2"
        local setting_value="$3"

        local service_section_found=0
        local proxy_setction_found=0

        while IFS= read -r line; do
            # 检测[Service]部分的开始
            if [[ "$line" == "[Service]" ]]; then
                service_section_found=1
            fi
            # 当在[Service]部分中找到设置时，更新
            if [[ $service_section_found -eq 1 && "$line" == "$setting_name"* ]]; then
                proxy_setction_found=1
                break
            fi
        done < "$service_file"

        # 找到[Service]
        if [[ $service_section_found -gt 0 ]]; then
            proxy="$setting_name=$setting_value\""
            # 如果[Service]部分中没有找到设置，则添加它
            if [[ proxy_setction_found -eq 0 ]]; then
                local_echo $setting_name not found in $fl, adding it.
                sed -i "/\[Service\]/a $proxy" "$service_file"
            else
                local_echo $setting_name found in $fl, changing it.
                sed -i "s#$setting_name=.*#$proxy#" "$service_file"
            fi
        else
            local_echo [Service] section not found in $fl.
        fi
    }

    add_proxy_if_missing $fl 'Environment="NO_PROXY' "$no_proxy"
    add_proxy_if_missing $fl 'Environment="HTTPS_PROXY' "$https_proxy"
    add_proxy_if_missing $fl 'Environment="HTTP_PROXY' "$http_proxy"
    
    systemctl daemon-reload
    echo "================== cat $fl | grep PROXY ================"
    cat $fl | grep PROXY

    # 重新加载systemd配置并提示重启服务
    service=$(basename $fl)
    systemctl restart $service
    sleep 2
}

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
