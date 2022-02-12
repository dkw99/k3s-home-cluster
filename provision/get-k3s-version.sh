#!/bin/bash
# Usage:
# ./get-k3s-release-version.sh
# output:
#

export REPO_ROOT=$(git rev-parse --show-toplevel)
. "$REPO_ROOT"/.config.env
# --- setup channel values
INSTALL_K3S_CHANNEL_URL=${INSTALL_K3S_CHANNEL_URL:-'https://update.k3s.io/v1-release/channels'}
INSTALL_K3S_CHANNEL=${INSTALL_K3S_CHANNEL:-'stable'}

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
# --- verify existence of network downloader executable ---
verify_downloader() {
    if [ -x "$(command -v wget)" ] ; then
        DOWNLOADER="wget"
    elif [ -x "$(command -v curl)" ]; then
        DOWNLOADER="curl"
    else
        echo "Could not find curl or wget, please install one." >&2
    fi
}

# --- get lrelease version
get_release_version() {

    if [ -n "${INSTALL_K3S_VERSION}" ]; then
        VERSION_K3S=${INSTALL_K3S_VERSION}
    else
        info "Finding release for channel ${INSTALL_K3S_CHANNEL}"
        version_url="${INSTALL_K3S_CHANNEL_URL}/${INSTALL_K3S_CHANNEL}"
        case "$DOWNLOADER" in
            curl)
                #info "found downloader executable '$DOWNLOADER'"
                VERSION_K3S=$(curl -w '%{url_effective}' -L -s -S ${version_url} -o /dev/null | sed -e 's|.*/||')
                ;;
            wget)
                #info "found downloader executable '$DOWNLOADER'"
                VERSION_K3S=$(wget -SqO /dev/null ${version_url} 2>&1 | grep -i Location | sed -e 's|.*/||')
                ;;
            *)
                fatal "Incorrect downloader executable '$DOWNLOADER'"
                ;;
        esac
    fi
    export K3S_VERSION=${VERSION_K3S}
    info "Setting K3S_VERSION to version ${VERSION_K3S}"
}

verify_downloader
get_release_version
