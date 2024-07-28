#!/bin/bash

bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh

install_tailscale () {
    curl -fsSL https://tailscale.com/install.sh | sh
}


for id in ${ids[@]}; do
    ip=$ip_segment.$id

    warn "============================================="
    warn "====== Installing on $ip ======"
    warn "============================================="

    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f install_tailscale); install_tailscale"

    sleep 5
done
