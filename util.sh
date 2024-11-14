#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
if [ -f $bash_path/base.config ]; then
    echo "source base.config"
    source $bash_path/base.config
else
    echo "base.config not exists"
fi

# 获取当前机器ip
get_localip() {
    ipaddr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' | grep $ip_segment)
    echo "$ipaddr"
}

error() {
    echo -e "\033[31m$@\033[0m"
}

info() {
    echo -e "\033[32m$@\033[0m"
}

warn() {
    echo -e "\033[33m$@\033[0m"
}

configure_network() {
    local id=$1
    qm set $id --ipconfig0 gw=$gateway,ip=$ip_segment.$id/$netmask
    qm set $id --nameserver $nameserver --searchdomain $searchdomain 
    # password
    qm set $id --ciuser root --cipassword Ingru$id
    # add ssh-key
    qm set $id --sshkey /root/.ssh/id_rsa.pub --sshkeys /root/.ssh/authorized_keys
}

create_vm() {
    local id=$1
    
    # 注意这里的绝对路径
    if [ $# -gt 1 ]; then
        img="$2"
    else
        img="/var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img"
    fi
    # Create a new virtual machine with the specified ID, name, memory, and CPU configuration
    qm create $id --name ubuntu$id
    # Import the disk image for the virtual machine with the specified ID from the specified image file
    qm importdisk $id $img local-lvm


    if [[ $id -eq 100 ]]; then
        size="200G"
    else
        size="80G"
    fi

    # set memory
    qm set $id --memory $memory --cores $cores --sockets 1 --cpu host
    # Configure the network settings for the virtual machine with the specified ID
    qm set $id --net0 virtio,bridge=vmbr0,firewall=0 --onboot 1 --ostype l26
    # Set the machine type for the virtual machine with the specified ID to q35, if not q35, GPU could not be mounted
    qm set $id --machine q35
    # Set the SCSI controller and disk for the virtual machine with the specified ID
    qm set $id --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$id-disk-0
    # Resize the disk for the virtual machine with the specified ID to 128GB
    qm resize $id scsi0 $size 

    qm set $id --ide0 local-lvm:cloudinit
    # Set the serial and VGA settings for the virtual machine with the specified ID.
    # The serial is set to socket and the VGA is set to serial0.
    qm set $id --serial0 socket --vga serial0
    # Set the boot options for the virtual machine with the specified ID.
    # The boot order is set to cd/dick/network and the boot disk is set to scsi0.
    qm set $id --boot cdn --bootdisk scsi0
    # qm set $id --cicustom "root=local:snippets/cloud-init.yml"
}

set_pci() {
    local id=$1
    local pci=$2
    qm set $id --hostpci0 host=$pci,pcie=1,rombar=1,x-vga=0
}

# ================================================
# sshd_config 
# ================================================
sshd_config () {
    if [ $# -gt 0 ]; then
        id=$1 
    else
        return 
    fi
    sed_replace () {
        fl=$1 
        sed -i 's/^#.*PermitRootLogin.*$/PermitRootLogin yes/' $fl 
        sed -i 's/^#.*PubkeyAuthentication.*$/PubkeyAuthentication yes/' $fl 
        sed -i 's/^#.*PasswordAuthentication.*$/PasswordAuthentication yes/' $fl 
    }
    if [ $id -gt 110 ] ; then
        sed_replace /etc/ssh/sshd_config
        rm /etc/ssh/sshd_config.d/*
        systemctl restart sshd
        echo "sshd Done"
    fi
}

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
            tar xvf tmux-3.4.tar.gz && cd tmux-3.4 && ./configure --prefix=/usr/local && make -j 4 && make install
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

# #################################
# k8s pull
# #################################

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
