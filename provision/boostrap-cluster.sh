#!/bin/sh
set -e
set -o noglob
# --- Environment setup ----
export REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}
source $REPO_ROOT/.config.env
# . $REPO_ROOT/provision/get-k3s-version.sh
export KUBECONFIG="$REPO_ROOT/provision/kubeconfig"
K3S_MASTER_HOSTNAME=${K3S_MASTER_HOSTNAMES}
K3S_MASTER_IP=$K3S_MASTER_IPS

# --- helper functions for logs ---
info()
{
    echo '[INFO] ' "$@"
}
warn()
{
    echo '[WARN] ' "$@" >&2
}
fatal()
{
    echo '[ERROR] ' "$@" >&2
    exit 1
}

need() {
    # Return failure if it doesn't exist or is no executable
    if [ -x "$(command -v $1)" ]; then
        return 0
    else
        echo "Binary '$1' is missing but required"
        return 1
    fi

}

need "curl"
need "ssh"
need "kubectl"
need "flux"



k3sMasterNode() {
  info "installing k3s master to $K3S_MASTER_HOSTNAME / $K3S_MASTER_IP"
  ssh -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$K3S_MASTER_IP" "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --tls-san $K3S_MASTER_HOSTNAME --disable servicelb --disable traefik --disable local-storage --disable metrics-server --flannel-backend=host-gw --write-kubeconfig-mode "0644"' INSTALL_K3S_VERSION='$K3S_VERSION' sh -"
  # --kube-apiserver-arg oidc-client-id=dex-k8s-authenticator --kube-apiserver-arg oidc-groups-claim=groups --kube-apiserver-arg oidc-issuer-url=https://dex.microserver.space --kube-apiserver-arg oidc-username-claim=email' INSTALL_K3S_VERSION='$K3S_VERSION' sh -"
  sleep 10
  info "Creating KUBECONFIG"
  if [ -r ${KUBECONFIG} ]; then
    info "Found existing KUBECONFIG at '${KUBECONFIG}'. creating backup"
    mv ${KUBECONFIG} ${KUBECONFIG}.bak
    info "Moved to '${KUBECONFIG}.bak'"


  fi

  ssh -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$K3S_MASTER_IP" " cat /etc/rancher/k3s/k3s.yaml | sed 's/server: https:\/\/127.0.0.1:6443/server: https:\/\/$K3S_MASTER_IP:6443/'" > "${KUBECONFIG}"
  info "Created '${KUBECONFIG}'"
  info "Copying kubeconfig to $HOME/.kube/config"
  cp ${KUBECONFIG} $HOME/.kube/config
  # export KUBECONFIG="./provision/kubeconfig"
  sleep 2
  NODE_TOKEN=$(ssh  -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$K3S_MASTER_IP" "cat /var/lib/rancher/k3s/server/node-token")
  info "Finished installing k3s to $K3S_MASTER_HOSTNAME / $K3S_MASTER_IP"
}

ks3amd64WorkerNodes() {
  NODE_TOKEN=$(ssh -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$K3S_MASTER_HOSTNAME" "sudo cat /var/lib/rancher/k3s/server/node-token")
  for node in $K3S_WORKERS_AMD64; do
    info "joining amd64 $node to $K3S_MASTER"
    EXTRA_ARGS=""
    ssh -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$node" "curl -sfL https://get.k3s.io | K3S_URL=https://k3os-a:6443 K3S_TOKEN=$NODE_TOKEN INSTALL_K3S_VERSION='$K3S_VERSION' sh -s - $EXTRA_ARGS"
  done
}

ks3armWorkerNodes() {
  NODE_TOKEN=$(ssh -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$K3S_MASTER_HOSTNAME" "sudo cat /var/lib/rancher/k3s/server/node-token")
  for node in $K3S_WORKERS_RPI; do
    info "joining pi4 $node to $K3S_MASTER"
    EXTRA_ARGS=""
    ssh -o "StrictHostKeyChecking=no" "$SSH_USERNAME"@"$node" "curl -sfL https://get.k3s.io | K3S_URL=https://k3os-a:6443 K3S_TOKEN=$NODE_TOKEN INSTALL_K3S_VERSION='$K3S_VERSION' sh -s - --node-taint arm=true:NoExecute --data-dir /mnt/usb/var/lib/rancher $EXTRA_ARGS"
  done
}
installFlux() {
    cd ${REPO_ROOT}
    . $REPO_ROOT/.config.env
    info "Sleeping for 10s to give cluster time to settle"
    sleep 10
    info "Setting up environment variables"
    info "Using kubeconfig: ${KUBECONFIG}"
    info "Installing flux..."
    # install flux
    kubectl --kubeconfig=${KUBECONFIG} create namespace flux-system --dry-run=client -o yaml | kubectl --kubeconfig=${KUBECONFIG} apply -f - > /dev/null 2>&1
    RESULT=$(kubectl --kubeconfig=$KUBECONFIG  get namespace flux-system -o wide 2>&1 | grep -c "Active")
    if [ $RESULT==1 ]; then
        info "Created flux-system namespace"
    fi
    sleep 2
    info "Creating SOPS decryption key with ${BOOTSTRAP_AGE_KEY}"
    RESULT=$(kubectl --kubeconfig="${KUBECONFIG}" get secret sops-age  -n flux-system 2>&1 | awk '$1=="sops-age"{print $3}')
    # if [ ! $RESULT==1 ]; then
        info "Creating SOPS decryption key with ${BOOTSTRAP_AGE_KEY}"
        kubectl --kubeconfig=${KUBECONFIG} -n flux-system create secret generic sops-age --from-file=age.agekey="${BOOTSTRAP_AGE_KEY}" > /dev/null 2>&1
    # else
       #  info "sops-age secret already installed"
    # fi
    sleep 2
    info "Installing flux to cluster....Pass 1 "
    kubectl --kubeconfig="${KUBECONFIG}" apply --kustomize=./cluster/base/flux-system > /dev/null 2>&1
    info "Done"
    info "Sleeping for 5s to settle"
    sleep 5
    info "Installing flux to cluster....Pass 2 "
    kubectl --kubeconfig="${KUBECONFIG}" apply --kustomize=./cluster/base/flux-system > /dev/null 2>&1
    info "Done"

}
# Start Main Script here

# k3sMasterNode
  installFlux
# ks3amd64WorkerNodes
# ks3armWorkerNodes

info "all done!"
kubectl --kubeconfig=${KUBECONFIG} get nodes -o=wide
