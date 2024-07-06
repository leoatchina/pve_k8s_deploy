#!/bin/bash
bash_path=$(cd "$(dirname "$0")";pwd)
source $bash_path/util.sh


ctrl_ip=$ip_segment.$masterid


k8s_cluster () {
    ip=$1
    ctrl_ip=$2
    warn "================================"
    warn "====== $ip ======"
    warn "================================"

    # Reset the kubelet service if it is active
    if [[ $(systemctl is-active kubelet) =~ ^activ ]]; then
        error "== $ip Kubelet service is running =="
        echo "y" | kubeadm reset
        rm -rf $HOME/.kube && mkdir -p $HOME/.kube
        rm -rf /etc/cni/net.d
        rm -rf /etc/kubernetes/manifests
    else
        warn "== $ip Kubelet service is not running =="
        rm -rf /etc/kubernetes/kubelet.conf
        rm -rf /etc/kubernetes/pki/ca.crt
    fi

    kubeadm_file=/tmp/kubeadm.txt
    mkdir -p /etc/cni/net.d /etc/kubernetes/manifests

    if [ "$ip" == "$ctrl_ip" ] ; then
        nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
        if [ -z "$nodes" ]; then
            info ========== no nodes ============== 
        else
            for node in $nodes; do
                # 对于每个节点，获取其污点信息
                taints=$(kubectl get node "$node" -o jsonpath='{.spec.taints[*].key}')
                if [ ! -z "$taints" ]; then
                    # 如果存在污点，逐个去除
                    for taint in $taints; do
                        warn "==  Removing taint $taint from $node =="
                        kubectl taint nodes "$node" $taint-
                    done
                else
                    info "=== No taints found on $node ==="
                fi
            done
        fi

        version=$(kubelet --version | awk '{print $2}')

        info ======== ctrl node init on $ip =========

        # Initialize the control node
        kubeadm init \
            --apiserver-advertise-address=$ctrl_ip \
            --node-name=$(hostname) \
            --kubernetes-version=$version \
            --service-cidr=$service_cidr \
            --pod-network-cidr=$pod_network_cidr | tee $kubeadm_file

        cp -f /etc/kubernetes/admin.conf $HOME/.kube/config


        # flannel net Initialize
        # kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        # sed -i "s#docker.io#docker.m.daocloud.io#g" /tmp/kube-flannel.yml
        # kubectl apply -f /tmp/kube-flannel.yml

        # calico
        # bash_path=$(cd "$(dirname "$0")";pwd)
        # echo $bash_path
        # cd /tmp && wget https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O /tmp/custom-resources.yaml
        # cd /tmp && wget https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml -O /tmp/tigera-operator.yaml
        # sed -i 's/name: default/name: kube-system/g' /tmp/custom-resources.yaml
        # sed -i 's/192.168.0.0/10.244.0.0/g' /tmp/custom-resources.yaml

        # kubectl apply -f /tmp/custom-resources.yaml
    else
        info ======== work node $ip join $ctrl_ip =========
        # Initialize a worker node
        ssh-keygen -f "/root/.ssh/known_hosts" -R $ctrl_ip
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:$kubeadm_file $kubeadm_file 
        # Join the worker node to the control node
        token=$(grep 'kubeadm join' $kubeadm_file | sed -n -e 's/^.*--token \(\S*\).*$/\1/p' | tail -1)
        token_hash=$(grep 'discovery\-token\-ca\-cert\-hash' $kubeadm_file | sed -n -e 's/^.*--discovery-token-ca-cert-hash \(\S*\).*$/\1/p' | tail -1)
        rm $kubeadm_file
        kubeadm join $ctrl_ip:6443 --token $token --discovery-token-ca-cert-hash $token_hash
        scp -o StrictHostKeyChecking=accept-new root@$ctrl_ip:/etc/kubernetes/admin.conf $HOME/.kube/config
    fi

    sed -i 's#--network-plugin=cni##' /var/lib/kubelet/kubeadm-flags.env
    

    cat > /etc/cni/net.d/10-flannel.conf <<EOF
{
  "name": "cbr0",
  "cniVersion": "0.2.0",
  "type": "flannel",
  "delegate": {
    "isDefaultGateway": true
  }
}
EOF
}

for id in ${ids[@]}; do
    if [[ "${no_ids[@]}" =~ "${id}" ]]; then
        warn $id not join k8s cluster
        continue
    fi
    
    ip=$ip_segment.$id

    echo
    ssh -o StrictHostKeyChecking=no root@$ip "$(declare -f k8s_cluster warn info error); k8s_cluster $ip $ctrl_ip"

done
