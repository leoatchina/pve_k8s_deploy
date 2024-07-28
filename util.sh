#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/base.config

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
