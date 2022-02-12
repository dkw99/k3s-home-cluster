#!/bin/sh
set -e
set -o noglob
export REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}
. $REPO_ROOT/.config.env
. $REPO_ROOT/provision/get-k3s-version.sh
export KUBECONFIG="$REPO_ROOT/provision/kubeconfig"
K3S_MASTER_HOSTNAME=${K3S_MASTER_HOSTNAMES}
K3S_MASTER_IP=$K3S_MASTER_IPS

# nodes
#K3S_MASTER="k3s-a"
#K3S_WORKERS_AMD64="k3s-b k3s-c k3s-d"
#K3S_WORKERS_RPI="pi4-a pi4-b pi4-c"
#K3S_VERSION="v1.18.8+k3s1"
#SETUP_USER="sysdkwise"
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
#

need() {
    # which "$1" &>/dev/null || die "Binary '$1' is missing but required"
    # Return failure if it doesn't exist or is no executable
    if [ -x "$(command -v $1)" ]; then
        return 0
    else
        echo "Binary '$1' is missing but required"
        return 1
    fi

}

need "kubectl"
# need "helm"
need "flux"


installFlux() {
    cd ${REPO_ROOT}
    info "Setting up environment variables"
    info "Using kubeconfig: ${KUBECONFIG}"
    info "Installing flux..."
    # install flux
    kubectl --kubeconfig=${KUBECONFIG} create namespace flux-system --dry-run=client -o yaml | kubectl --kubeconfig=${KUBECONFIG} apply -f - > /dev/null 2>&1
    RESULT=$(kubectl --kubeconfig=$KUBECONFIG  get namespace flux-system -o wide 2>&1 | grep -c "Active")
    if [ $RESULT==1 ]; then
        info "Created flux-system namespace"
    fi
    info "Creating SOPS decryption key with ${BOOTSTRAP_AGE_KEY}"
    RESULT=$(kubectl --kubeconfig="${KUBECONFIG}" get secret sops-age  -n flux-system 2>&1 | awk '$1=="sops-age"{print $3}')
    if [ ! $RESULT==1 ]; then
        info "Creating SOPS decryption key with ${BOOTSTRAP_AGE_KEY}"
        kubectl --kubeconfig=${KUBECONFIG} -n flux-system create secret generic sops-age --from-file=age.agekey="${BOOTSTRAP_AGE_KEY}" > /dev/null 2>&1
    else
        info "sops-age secret already installed"
    fi
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

  installFlux
# "$REPO_ROOT"/setup/bootstrap-objects.sh

# bootstrap vault
# "$REPO_ROOT"/setup/bootstrap-vault.sh

info "all done!"
kubectl --kubeconfig=${KUBECONFIG} get nodes -o=wide
