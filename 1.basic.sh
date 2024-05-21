#!/bin/bash
swapoff -a
sed -ri 's/.*swap.*/#&/' /etc/fstab

if [ $# -gt 0 ] && [ $1 -gt 104 ]; then
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*
    sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo "sshd Done"
fi

sed -i 's/http:\/\/archive.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's/http:\/\/security.ubuntu.com/http:\/\/mirrors.aliyun.com/g' /etc/apt/sources.list

timedatectl set-timezone Asia/Shanghai
apt update -y 
apt install -y libevent-dev ncurses-dev bison pkg-config build-essential
apt install -y vim git ripgrep universal-ctags htop zip unip
apt install -y apt-transport-https ca-certificates curl software-properties-common
apt install -y lua5.3 nfs-common net-tools sshfs


# tmux
mkdir -p ~/.local && rm /tmp/tmux-3.4.tar.gz
cd /tmp && wget https://github.com/tmux/tmux/releases/download/3.4/tmux-3.4.tar.gz && \
    tar xvf tmux-3.4.tar.gz && cd tmux-3.4 && ./configure --prefix=/usr && make && make install

apt install -y python3-pip python3-venv && pip install neovim

mkdir -p /data/nfs

cat << EOF | tee ~/.vimrc.test
if has('nvim')
    source ~/.leovim/boostup/init.vim
endif
EOF

if [ -d ~/.leovim ]; then
    cd ~/.leovim && git pull
else
    git clone https://gitee.com/leoatchina/leovim.git ~/.leovim
fi
