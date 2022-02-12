# Infrastructure

Proxmox VM host
1 x Alpine Linux VM

- [[Alpine](https://alpinelinux.org/)]  - light weight linux operating system that supports running running all kinds of home related workloads in Kubernetes
- not used - [Ubuntu](https://ubuntu.com/download/server) - this is a pretty universal operating system that supports running all kinds of home related workloads in Kubernetes
- not used - [Ansible](https://www.ansible.com) - this will be used to provision the Ubuntu operating system to be ready for Kubernetes and also to install k3s
- not used - [Terraform](https://www.terraform.io) - in order to help with the DNS settings this will be used to provision an already existing Cloudflare domain and DNS settings

## :computer:&nbsp; Infrastructure

See the [k3s setup](provision/README.md) for more detail about hardware and infrastructure

## :gear:&nbsp; Setup

See [setup](provision/README.md) for more detail about setup & bootstrapping a new cluster

## :memo:&nbsp; Prerequisites

### :computer:&nbsp; Systems

- One or more nodes with a fresh install of [Ubuntu Server 20.04](https://ubuntu.com/download/server). These nodes can be bare metal or VMs.
- A [Cloudflare](https://www.cloudflare.com/) account with a domain, this will be managed by Terraform.
- Some experience in debugging problems and a positive attitude ;)


## Notes

Kernel: linux-lts
apk add nfs-common
```sh
apk add --no-cache linux-lts nfs-utils curl nano wget qemu-guest-agent

echo "cgroup /sys/fs/cgroup cgroup defaults 0 0" >> /etc/fstab

cat > /etc/cgconfig.conf <<EOF
mount {
  cpuacct = /cgroup/cpuacct;
  memory = /cgroup/memory;
  devices = /cgroup/devices;
  freezer = /cgroup/freezer;
  net_cls = /cgroup/net_cls;
  blkio = /cgroup/blkio;
  cpuset = /cgroup/cpuset;
  cpu = /cgroup/cpu;
}
EOF

sed -i 's/default_kernel_opts="pax_nouderef quiet rootfstype=ext4"/default_kernel_opts="pax_nouderef quiet rootfstype=ext4 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"/g' /etc/update-extlinux.conf

rc-update add rpcbind

rc-update add nfsclient

reboot
```


Add cni-plugins

```
apk add --no-cache cni-plugins --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
export PATH=$PATH:/usr/share/cni-plugins/bin
echo -e '#!/bin/sh\nexport PATH=$PATH:/usr/share/cni-plugins/bin' > /etc/profile.d/cni.sh
apk add iptables
```

```

##
```
./bootsrap-cluster.sh

```

```
$ kubectl get nodes
NAME     STATUS   ROLES    AGE     VERSION
server   Ready    master   3m40s   v1.17.4+k3s1

# token: /var/lib/rancher/k3s/server/node-token
```
