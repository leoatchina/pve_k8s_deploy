#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh



# ================================================
# install_softwares 
# ================================================
install_softwares() {
    swapoff -a
    sed -ri 's/.*swap.*/#&/' /etc/fstab

    sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
    sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list

    timedatectl set-timezone Asia/Shanghai
    apt update -y 
    apt install -y libevent-dev ncurses-dev bison pkg-config build-essential
    apt install -y vim git ripgrep universal-ctags htop zip unzip
    apt install -y apt-transport-https ca-certificates curl software-properties-common
    apt install -y lua5.3 nfs-common net-tools sshfs
    apt install -y python3-pip python3-venv && pip install neovim

    # tmux
    apt remove -y tmux
    if [ ! -f /usr/bin/tmux ]; then
        [ -f /tmp/tmux-3.4.tar.gz ] && rm /tmp/tmux-3.4.tar.gz
        cd /tmp && wget https://github.com/tmux/tmux/releases/download/3.4/tmux-3.4.tar.gz && \
            tar xvf tmux-3.4.tar.gz && cd tmux-3.4 && ./configure --prefix=/usr && make -j 4 && make install
    fi

    mkdir -p /data/nfs
    # leovim
    mkdir -p /root/.local
    cat << EOF | tee ~/.vimrc.local
    if has('nvim')
        source ~/.leovim/conf.d/init.vim
    endif
EOF
    if [ -d ~/.leovim ]; then
        cd ~/.leovim && git pull
    else
        git clone https://gitee.com/leoatchina/leovim.git ~/.leovim
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

    # Generate the default containerd configuration file
    # /usr/bin/containerd config default > /etc/containerd/config.toml

    # Modify the containerd configuration file to use a different container image registry
    fl="/etc/containerd/config.toml"
    sed -i "s#registry.k8s.io/pause:3.8#registry.aliyuncs.com/google_containers/pause:3.9#g" $fl

    # Enable systemd cgroup support in containerd
    sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" $fl
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
    curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/$version/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/$version/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
}



    # 代理设置
set_proxy () {
    
    http_proxy="$1"
    https_proxy="$2"
    no_proxy="$3"
    # 检查并添加代理设置
   add_proxy_if_missing() {
        local service_file="$1"
        local setting_name="$2"
        local setting_value="$3"
        local service_section_found=0

        while IFS= read -r line; do
            # 检测[Service]部分的开始
            if [[ "$line" == "[Service]" ]]; then
                service_section_found=1
            fi

            # 当在[Service]部分中找到设置时，返回
            if [[ $service_section_found -eq 1 && "$line" == "$setting_name="* ]]; then
                return
            fi
        done < "$service_file"

        # 如果[Service]部分中没有找到设置，则添加它
        sed -i "/\[Service\]/a $setting_name=$setting_value\"" "$service_file"
    }

    # 挂代理
    fl=/usr/lib/systemd/system/kubelet.service
    add_proxy_if_missing $fl "Environment=\"NO_PROXY" "$no_proxy"
    add_proxy_if_missing $fl "Environment=\"HTTPS_PROXY" "$https_proxy"
    add_proxy_if_missing $fl "Environment=\"HTTP_PROXY" "$http_proxy"
    echo $fl
    cat $fl | grep PROXY

    fl=/usr/lib/systemd/system/containerd.service
    add_proxy_if_missing $fl "Environment=\"NO_PROXY" "$no_proxy"
    add_proxy_if_missing $fl "Environment=\"HTTPS_PROXY" "$https_proxy"
    add_proxy_if_missing $fl "Environment=\"HTTP_PROXY" "$http_proxy"
    echo $fl
    cat $fl | grep PROXY


    # 重新加载systemd配置并提示重启服务
    systemctl daemon-reload
    # Restart kubelet service
    systemctl restart kubelet containerd

}



pull_image () {
    images=$(kubeadm config images list)
    echo ===== images need =====
    for image in $images
    do
        echo $image
    done
    echo

    echo ===== images exist =====
    # List the existing images
    ctr image list | awk 'NR>1 {print $1":"$2}'
    echo ========================

    max_retries=3

    # 正式pull

    for image in $images; do
        retry=0
        # Check if the image is already pulled on the specified node
        if ctr image list | grep -q "$image"; then
            echo "$image already pulled."
        else
            while [ $retry -lt $max_retries ]
            echo "==== pulling $image ===="
            do
                if ctr image pull "$image"; then
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
                echo "image pull failed after $max_retries attempts."
                exit 1
            fi
        fi
    done
    crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
}



for id in ${ids[@]}; do
    ip=$ip_segment.$id

    echo 
    warn "================================"
    warn "====== $ip ======"
    warn "================================"

    echo
    info "====== Installed softwares on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_softwares); install_softwares"

    echo
    info "====== Installed containerd on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_containerd); install_containerd"

    echo
    info "====== Installed k8s on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_k8s); install_k8s $k8s_version"

    echo
    info "====== Set proxy on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f set_proxy); set_proxy $http_proxy $https_proxy $no_proxy"

    echo
    info "====== K8s pull on $ip ======"
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f pull_image); pull_image "

done
