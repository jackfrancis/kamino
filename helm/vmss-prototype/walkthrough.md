# vmss-prototype walkthrough

This walkthrough will demonstrate a concrete operational session that employs `vmss-prototype` to freshen the OS configuration on a node pool. This solution scales nicely, although we hope that demonstrating on a 10 node pool is sufficient to suggest the value of more rapidly, reliably freshening large (> 100 nodes) clusters.

Initially, let's take a look at our example cluster:

```sh
$ k get nodes -o wide
NAME                                 STATUS   ROLES    AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-agentpool1-26100436-vmss000000   Ready    agent    2m12s   v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000001   Ready    agent    119s    v1.20.1   10.240.0.35    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000002   Ready    agent    87s     v1.20.1   10.240.0.66    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000003   Ready    agent    2m11s   v1.20.1   10.240.0.97    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000004   Ready    agent    2m6s    v1.20.1   10.240.0.128   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000005   Ready    agent    2m8s    v1.20.1   10.240.0.159   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000006   Ready    agent    2m7s    v1.20.1   10.240.0.190   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000007   Ready    agent    118s    v1.20.1   10.240.0.221   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000008   Ready    agent    2m16s   v1.20.1   10.240.0.252   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000009   Ready    agent    2m6s    v1.20.1   10.240.1.27    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-master-26100436-0                Ready    master   2m40s   v1.20.1   10.255.255.5   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
```

By logging onto one of the nodes, I can see that there are several security patches needed (by convention AKS Engine builds clusters with a ssh NAT path to the "first"):

```sh
$ ssh k8s-agentpool1-26100436-vmss000000

Authorized uses only. All activity may be monitored and reported.
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1032-azure x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Fri Jan  8 20:36:12 UTC 2021

  System load:  0.27               Processes:              160
  Usage of /:   32.1% of 28.90GB   Users logged in:        0
  Memory usage: 7%                 IP address for eth0:    10.240.0.4
  Swap usage:   0%                 IP address for docker0: 172.17.0.1

50 packages can be updated.
33 updates are security updates.


Last login: Fri Jan  8 20:36:08 2021 from 10.255.255.5
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.
```

Let's make sure that list is fresh by running `apt update`:

```sh
azureuser@k8s-agentpool1-26100436-vmss000000:~$ sudo apt update
Hit:1 https://packages.microsoft.com/ubuntu/18.04/prod bionic InRelease
Hit:2 https://repo.iovisor.org/apt/bionic bionic InRelease
Get:3 http://security.ubuntu.com/ubuntu bionic-security InRelease [88.7 kB]
Hit:4 http://azure.archive.ubuntu.com/ubuntu bionic InRelease
Hit:5 http://azure.archive.ubuntu.com/ubuntu bionic-updates InRelease
Hit:6 http://azure.archive.ubuntu.com/ubuntu bionic-backports InRelease
Fetched 88.7 kB in 3s (29.5 kB/s)
Reading package lists... Done
Building dependency tree
Reading state information... Done
41 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

Now, let's get them all:

```sh
azureuser@k8s-agentpool1-26100436-vmss000000:~$ sudo apt-get dist-upgrade
Reading package lists... Done
Building dependency tree
Reading state information... Done
Calculating upgrade... Done
The following packages were automatically installed and are no longer required:
  libapr1 libaprutil1 libauparse0 libopts25 linux-headers-4.15.0-124
Use 'sudo apt autoremove' to remove them.
The following NEW packages will be installed:
  linux-azure-5.4-cloud-tools-5.4.0-1036 linux-azure-5.4-headers-5.4.0-1036 linux-azure-5.4-tools-5.4.0-1036 linux-cloud-tools-5.4.0-1036-azure linux-headers-5.4.0-1036-azure linux-image-5.4.0-1036-azure
  linux-modules-5.4.0-1036-azure linux-modules-extra-5.4.0-1036-azure linux-tools-5.4.0-1036-azure
The following packages will be upgraded:
  apport apt apt-transport-https apt-utils blobfuse cloud-init curl libapt-inst2.0 libapt-pkg5.0 libc-bin libc-dev-bin libc6 libc6-dev libcurl3-gnutls libcurl4 libp11-kit0 libsasl2-2 libsasl2-modules
  libsasl2-modules-db libssl1.0.0 libssl1.1 linux-azure linux-cloud-tools-azure linux-cloud-tools-common linux-headers-azure linux-image-azure linux-libc-dev linux-tools-azure linux-tools-common locales
  multiarch-support openssl python-apt-common python3-apport python3-apt python3-distupgrade python3-problem-report tzdata ubuntu-release-upgrader-core update-notifier-common wireless-regdb
41 upgraded, 9 newly installed, 0 to remove and 0 not upgraded.
Need to get 79.3 MB of archives.
After this operation, 241 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
<output truncated>
<...>
done
```

While we're here, let's manually invoke `unattended-upgrade` to get those immediately:

```sh
azureuser@k8s-agentpool1-26100436-vmss000000:~$ sudo unattended-upgrade
azureuser@k8s-agentpool1-26100436-vmss000000:~$ echo $?
0
```

At this point, we can confirm that there's nothing else to get:

```sh
$ sudo apt list --upgradable
Listing... Done
```

Compare this to the remaining nodes in the cluster:

```sh
$ for i in `seq 1 9`; do ssh k8s-agentpool1-26100436-vmss00000$i "sudo apt list --upgradable | wc -l"; done

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

18

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

18

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42
```

Logging back onto our updated node in this pool, we can observe that a reboot is required to actually apply all updated patches:

```sh
azureuser@k8s-agentpool1-26100436-vmss000000:~$ cat /var/run/reboot-required
*** System restart required ***
```

So, let's cordon + drain that node from the cluster...:

```sh
$ k cordon k8s-agentpool1-26100436-vmss000000
node/k8s-agentpool1-26100436-vmss000000 cordoned
$ k get node k8s-agentpool1-26100436-vmss000000
NAME                                 STATUS                     ROLES   AGE   VERSION
k8s-agentpool1-26100436-vmss000000   Ready,SchedulingDisabled   agent   18m   v1.20.1
$ k drain --ignore-daemonsets --delete-emptydir-data --force --grace-period 300 --timeout 900s k8s-agentpool1-26100436-vmss000000
node/k8s-agentpool1-26100436-vmss000000 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-m8rzb, kube-system/azure-ip-masq-agent-wqkxb, kube-system/blobfuse-flexvol-installer-8d5fz, kube-system/csi-secrets-store-provider-azure-77gbz, kube-system/csi-secrets-store-s5jp9, kube-system/kube-proxy-sck72
node/k8s-agentpool1-26100436-vmss000000 drained
$ echo $?
0
```

And reboot it:

```sh
azureuser@k8s-agentpool1-26100436-vmss000000:~$ sudo reboot && exit
Connection to k8s-agentpool1-26100436-vmss000000 closed by remote host.
Connection to k8s-agentpool1-26100436-vmss000000 closed.
```

Verify that the reboot is successful:

```sh
$ ssh k8s-agentpool1-26100436-vmss000000

Authorized uses only. All activity may be monitored and reported.
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1036-azure x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Fri Jan  8 20:56:16 UTC 2021

  System load:  1.58               Processes:              167
  Usage of /:   35.2% of 28.90GB   Users logged in:        0
  Memory usage: 6%                 IP address for eth0:    10.240.0.4
  Swap usage:   0%                 IP address for docker0: 172.17.0.1

0 packages can be updated.
0 of these updates are security updates.


Last login: Fri Jan  8 20:46:55 2021 from 10.255.255.5
azureuser@k8s-agentpool1-26100436-vmss000000:~$ sudo apt list --upgradable
Listing... Done
azureuser@k8s-agentpool1-26100436-vmss000000:~$ ls -la /var/run/reboot-required
ls: cannot access '/var/run/reboot-required': No such file or directory
```

Node `k8s-agentpool1-26100436-vmss000000` is looking good! Just for fun, let's fingerprint this node as another mark of what can be done using `vmss-prototype`:

```sh
azureuser@k8s-agentpool1-26100436-vmss000000:~$ ls -la /var/log/vmss-prototype-was-here
ls: cannot access '/var/log/vmss-prototype-was-here': No such file or directory
azureuser@k8s-agentpool1-26100436-vmss000000:~$ sudo touch /var/log/vmss-prototype-was-here
```

We can now return the node to service, so that we can use it as the target node in a `vmss-prototype` run (`vmss-prototype` requires a `Ready` node as part of its initial validation that a node VM is an appropriate candidate for taking a snapshot and propagating to the VMSS model):

```sh
$ k uncordon k8s-agentpool1-26100436-vmss000000
node/k8s-agentpool1-26100436-vmss000000 uncordoned
FrancisBookMS:aks-engine jackfrancis$ k get node k8s-agentpool1-26100436-vmss000000
NAME                                 STATUS   ROLES   AGE   VERSION
k8s-agentpool1-26100436-vmss000000   Ready    agent   29m   v1.20.1
```

It is at this point that you would want to operationally validate this node. Perhaps run replicas of your production workloads on it using an appropriate nodeSelector, to confidently conclude that the changed node is indeed running against an OS configuration that you want to replicate across your entire node pool.

Finally, we begin the long-running task of running vmss-prototype against the updated node:

```sh
$ helm install --repo https://jackfrancis.github.io/kamino/ update-from-k8s-agentpool1-26100436-vmss000000 vmss-prototype --namespace default --set kamino.scheduleOnControlPlane=true --set kamino.newUpdatedNodes=10 --set kamino.targetNode=k8s-agentpool1-26100436-vmss000000
NAME: update-from-k8s-agentpool1-26100436-vmss000000
LAST DEPLOYED: Fri Jan  8 13:04:57 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Note in the above `helm install` invocation, we include the `--set kamino.newUpdatedNodes=10` option. We do this to easily demonstrate the effects of building new nodes in the VMSS node pool from the target node.

Before long, we'll see that node once again go out of service due to `vmss-prototype` needing to deallocate and take a snapshot image of its OS disk:

```sh
$ k get nodes -o wide -w
NAME                                 STATUS   ROLES    AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-agentpool1-26100436-vmss000000   Ready    agent    36m   v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000001   Ready    agent    35m   v1.20.1   10.240.0.35    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000002   Ready    agent    35m   v1.20.1   10.240.0.66    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000003   Ready    agent    36m   v1.20.1   10.240.0.97    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000004   Ready    agent    36m   v1.20.1   10.240.0.128   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000005   Ready    agent    36m   v1.20.1   10.240.0.159   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000006   Ready    agent    36m   v1.20.1   10.240.0.190   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000007   Ready    agent    35m   v1.20.1   10.240.0.221   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000008   Ready    agent    36m   v1.20.1   10.240.0.252   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000009   Ready    agent    36m   v1.20.1   10.240.1.27    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-master-26100436-0                Ready    master   36m   v1.20.1   10.255.255.5   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000003   Ready    agent    36m   v1.20.1   10.240.0.97    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000000   Ready    agent    36m   v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000000   Ready,SchedulingDisabled   agent    36m   v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
```

Eventually, after the OS disk image snapshot is taken of that node VMSS instance, the instance will be deleted, and the node will be permanently removed from the cluster:

```sh
$ k get node k8s-agentpool1-26100436-vmss000000
Error from server (NotFound): nodes "k8s-agentpool1-26100436-vmss000000" not found
```

It takes a long time (between 30 mins and 2 hours) to create and replicate a new Shared Image Gallery Image (which is the resource type we use to re-use the OS image snapshot across future VMSS instances). Take a break and relax. Eventually, the entire progression of `vmss-prototype` can be viewd via the pod logs:

```sh
$ k logs kamino-gen-k8s-agentpool1-26100436-vmss-l4gzw -f
CMD: ['/usr/bin/vmss-prototype' '--in-cluster' '--log-level' 'INFO' 'update' '--target-node' 'k8s-agentpool1-26100436-vmss000000' '--new-updated-nodes' '10' '--grace-period' '300' '--max-history' '3']
INFO: ===> Executing command: ['az' 'cloud' 'set' '--name' 'AzureCloud']
INFO: ===> Executing command: ['az' 'login' '--identity']
INFO: ===> Executing command: ['az' 'account' 'set' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce']
INFO: ===> Executing command: ['kubectl' 'get' 'node' 'k8s-agentpool1-26100436-vmss000000']
INFO: ===> Executing command: ['az' 'sig' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813']
INFO: ===> Executing command: ['az' 'sig' 'create' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--description' 'Kamino VMSS images']
INFO: Processing VMSS k8s-agentpool1-26100436-vmss
INFO: ===> Executing command: ['az' 'sig' 'image-definition' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--gallery-image-definition' 'kamino-k8s-agentpool1-26100436-vmss-prototype']
INFO: ===> Executing command: ['az' 'sig' 'image-definition' 'create' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--gallery-image-definition' 'kamino-k8s-agentpool1-26100436-vmss-prototype' '--publisher' 'VMSS-Prototype-Pattern' '--offer' 'kubernetes-westus2-17813' '--sku' 'k8s-agentpool1-26100436-vmss' '--os-type' 'Linux' '--os-state' 'generalized']
INFO: ===> Executing command: ['az' 'sig' 'image-version' 'list' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--gallery-image-definition' 'kamino-k8s-agentpool1-26100436-vmss-prototype']
INFO: ===> Executing command: ['az' 'snapshot' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'snapshot_k8s-agentpool1-26100436-vmss']
INFO: ===> Executing command: ['az' 'vmss' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss' '--instance-id' '0']
INFO: ===> Executing command: ['kubectl' 'annotate' 'node' 'k8s-agentpool1-26100436-vmss000000' 'cluster-autoscaler.kubernetes.io/scale-down-disabled=true' '--overwrite']
INFO: ===> Executing command: ['kubectl' 'cordon' 'k8s-agentpool1-26100436-vmss000000']
INFO: ===> Executing command: ['kubectl' 'drain' '--ignore-daemonsets' '--delete-local-data' '--force' '--grace-period' '300' '--timeout' '900s' 'k8s-agentpool1-26100436-vmss000000']
INFO: ===> Completed in 0.18s: ['kubectl' 'drain' '--ignore-daemonsets' '--delete-local-data' '--force' '--grace-period' '300' '--timeout' '900s' 'k8s-agentpool1-26100436-vmss000000'] # RC=0
INFO: ===> Executing command: ['az' 'vmss' 'deallocate' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss' '--instance-ids' '0']
INFO: ===> Completed in 152.41s: ['az' 'vmss' 'deallocate' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss' '--instance-ids' '0'] # RC=0
INFO: ===> Executing command: ['az' 'snapshot' 'create' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'snapshot_k8s-agentpool1-26100436-vmss' '--source' '/subscriptions/aa3d3369-e814-4495-899d-d31e8d7d09ce/resourceGroups/kubernetes-westus2-17813/providers/Microsoft.Compute/disks/k8s-agentpool1-26100k8s-agentpool1-261004OS__1_895f47c2b4bb474a8eb24b32452b94b2' '--tags' 'BuiltFrom=k8s-agentpool1-26100436-vmss000000' 'BuiltAt=2021-01-08 21:09:34.255642']
INFO: ===> Executing command: ['az' 'vmss' 'delete-instances' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss' '--instance-ids' '0' '--no-wait']
INFO: ===> Executing command: ['kubectl' 'uncordon' 'k8s-agentpool1-26100436-vmss000000']
INFO: ===> Executing command: ['kubectl' 'annotate' 'node' 'k8s-agentpool1-26100436-vmss000000' 'cluster-autoscaler.kubernetes.io/scale-down-disabled-']
INFO: Creating sig image version - this can take quite a long time...
INFO: ===> Executing command: ['az' 'sig' 'image-version' 'create' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--gallery-image-definition' 'kamino-k8s-agentpool1-26100436-vmss-prototype' '--gallery-image-version' '2021.01.08' '--replica-count' '3' '--os-snapshot' 'snapshot_k8s-agentpool1-26100436-vmss' '--tags' 'BuiltFrom=k8s-agentpool1-26100436-vmss000000' 'BuiltAt=2021-01-08 21:09:34.255642' '--storage-account-type' 'Standard_ZRS']
INFO: ===> Completed in 5291.25s: ['az' 'sig' 'image-version' 'create' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--gallery-image-definition' 'kamino-k8s-agentpool1-26100436-vmss-prototype' '--gallery-image-version' '2021.01.08' '--replica-count' '3' '--os-snapshot' 'snapshot_k8s-agentpool1-26100436-vmss' '--tags' 'BuiltFrom=k8s-agentpool1-26100436-vmss000000' 'BuiltAt=2021-01-08 21:09:34.255642' '--storage-account-type' 'Standard_ZRS'] # RC=0
INFO: ===> Executing command: ['az' 'snapshot' 'delete' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'snapshot_k8s-agentpool1-26100436-vmss']
INFO: Latest image: /subscriptions/aa3d3369-e814-4495-899d-d31e8d7d09ce/resourceGroups/kubernetes-westus2-17813/providers/Microsoft.Compute/galleries/SIG_kubernetes_westus2_17813/images/kamino-k8s-agentpool1-26100436-vmss-prototype/versions/2021.01.08
INFO: ===> Executing command: ['az' 'sig' 'image-version' 'list' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--gallery-name' 'SIG_kubernetes_westus2_17813' '--gallery-image-definition' 'kamino-k8s-agentpool1-26100436-vmss-prototype']
INFO: ===> Executing command: ['az' 'vmss' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss']
INFO: ===> Executing command: ['az' 'vmss' 'update' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss' '--set' 'virtualMachineProfile.storageProfile.imageReference.id=/subscriptions/aa3d3369-e814-4495-899d-d31e8d7d09ce/resourceGroups/kubernetes-westus2-17813/providers/Microsoft.Compute/galleries/SIG_kubernetes_westus2_17813/images/kamino-k8s-agentpool1-26100436-vmss-prototype' 'virtualMachineProfile.storageProfile.imageReference.sku=null' 'virtualMachineProfile.storageProfile.imageReference.offer=null' 'virtualMachineProfile.storageProfile.imageReference.publisher=null' 'virtualMachineProfile.storageProfile.imageReference.version=null' 'virtualMachineProfile.osProfile.customData=I2Nsb3VkLWNvbmZpZwo=']
INFO: ===> Executing command: ['az' 'vmss' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss']
INFO: ===> Executing command: ['az' 'vmss' 'extension' 'list' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--vmss-name' 'k8s-agentpool1-26100436-vmss']
INFO: ===> Executing command: ['az' 'vmss' 'extension' 'delete' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--vmss-name' 'k8s-agentpool1-26100436-vmss' '--name' 'vmssCSE']
INFO: ===> Executing command: ['az' 'vmss' 'show' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss']
INFO: ===> Executing command: ['az' 'vmss' 'update' '--subscription' 'aa3d3369-e814-4495-899d-d31e8d7d09ce' '--resource-group' 'kubernetes-westus2-17813' '--name' 'k8s-agentpool1-26100436-vmss' '--set' 'sku.capacity=19' '--no-wait']
```

(Narrator: "A good while later...")

We now see our 10 new nodes, as requested by the `--set kamino.newUpdatedNodes=10` option:

```sh
$ k get nodes -o wide
NAME                                 STATUS   ROLES    AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-agentpool1-26100436-vmss000001   Ready    agent    134m    v1.20.1   10.240.0.35    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000002   Ready    agent    133m    v1.20.1   10.240.0.66    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000003   Ready    agent    134m    v1.20.1   10.240.0.97    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000004   Ready    agent    134m    v1.20.1   10.240.0.128   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000005   Ready    agent    134m    v1.20.1   10.240.0.159   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000006   Ready    agent    134m    v1.20.1   10.240.0.190   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000007   Ready    agent    134m    v1.20.1   10.240.0.221   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000008   Ready    agent    134m    v1.20.1   10.240.0.252   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000009   Ready    agent    134m    v1.20.1   10.240.1.27    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000a   Ready    agent    3m28s   v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000b   Ready    agent    3m18s   v1.20.1   10.240.1.88    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000c   Ready    agent    3m14s   v1.20.1   10.240.1.119   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000d   Ready    agent    3m25s   v1.20.1   10.240.1.150   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000e   Ready    agent    3m18s   v1.20.1   10.240.1.181   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000f   Ready    agent    3m28s   v1.20.1   10.240.1.212   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000g   Ready    agent    3m20s   v1.20.1   10.240.1.243   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000h   Ready    agent    2m14s   v1.20.1   10.240.2.18    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000i   Ready    agent    3m28s   v1.20.1   10.240.2.49    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000j   Ready    agent    3m48s   v1.20.1   10.240.2.80    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-master-26100436-0                Ready    master   134m    v1.20.1   10.255.255.5   <non
```

Now, let's confirm that these new nodes are all running the latest bits!

```sh
$ for i in {a..j}; do ssh k8s-agentpool1-26100436-vmss00000$i "sudo apt list --upgradable | wc -l && ls -la /var/log/vmss-prototype-was-here"; done

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here
```

Everything is looking good. `apt` is telling us that we don't have any updates (inferred by counting the number of stdout lines). Compare again to one of the original nodes:

```sh
$ ssh k8s-agentpool1-26100436-vmss000001 "sudo apt list --upgradable | wc -l && ls -la /var/log/vmss-prototype-was-here"

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

42
ls: cannot access '/var/log/vmss-prototype-was-here': No such file or directory
```

Just to prove that independent of having to invoke a helm release of `vmss-prototype` we've meaningfully updated the VMSS model for this node pool, let's do a simple scale out by one. There are many ways to do this, we'll demonstrate using the `az` command line. Recall that we originally begun this exercise on a cluster with a VMSS node pool of 10 nodes. We then installed a release of `vmss-prototype` via helm using the `--set kamino.newUpdatedNodes=10` option. During that job we lost one node (the target node, in order to deallocation and grab a snapshot of its OS disk image), and then added 10 more. Which means we now have 19. So we'll set the VMSS capacity to 20 to increase the count by 1:

```sh
$ az vmss update --resource-group kubernetes-westus2-17813 --name k8s-agentpool1-26100436-vmss --set sku.capacity=20 --no-wait
```

(Again, we're using the name of the resource group, and of the VMSS, that happen to be present in the example cluster here.)

By waiting for the node to arrive, we can easily identify it:

```sh
$ k get nodes -o wide -w
NAME                                 STATUS   ROLES    AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-agentpool1-26100436-vmss000001   Ready    agent    149m   v1.20.1   10.240.0.35    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000002   Ready    agent    148m   v1.20.1   10.240.0.66    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000003   Ready    agent    149m   v1.20.1   10.240.0.97    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000004   Ready    agent    149m   v1.20.1   10.240.0.128   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000005   Ready    agent    149m   v1.20.1   10.240.0.159   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000006   Ready    agent    149m   v1.20.1   10.240.0.190   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000007   Ready    agent    149m   v1.20.1   10.240.0.221   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000008   Ready    agent    149m   v1.20.1   10.240.0.252   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000009   Ready    agent    149m   v1.20.1   10.240.1.27    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000a   Ready    agent    18m    v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000b   Ready    agent    18m    v1.20.1   10.240.1.88    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000c   Ready    agent    18m    v1.20.1   10.240.1.119   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000d   Ready    agent    18m    v1.20.1   10.240.1.150   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000e   Ready    agent    18m    v1.20.1   10.240.1.181   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000f   Ready    agent    18m    v1.20.1   10.240.1.212   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000g   Ready    agent    18m    v1.20.1   10.240.1.243   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000h   Ready    agent    17m    v1.20.1   10.240.2.18    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000i   Ready    agent    18m    v1.20.1   10.240.2.49    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000j   Ready    agent    18m    v1.20.1   10.240.2.80    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-master-26100436-0                Ready    master   149m   v1.20.1   10.255.255.5   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000k   NotReady   <none>   0s     v1.20.1   10.240.2.111   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000k   NotReady   <none>   0s     v1.20.1   10.240.2.111   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000k   NotReady   <none>   0s     v1.20.1   10.240.2.111   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000k   Ready      <none>   10s    v1.20.1   10.240.2.111   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
```

That `k`-suffixed node is our mark! Let's validate that it has all the OS updates and sentinel file we're using to positively identify nodes built from the prototype of the original target node:

```sh
$ ssh k8s-agentpool1-26100436-vmss00000k "sudo apt list --upgradable | wc -l && ls -la /var/log/vmss-prototype-was-here"

Authorized uses only. All activity may be monitored and reported.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

1
-rw-r----- 1 root root 0 Jan  8 20:58 /var/log/vmss-prototype-was-here
```

Looking good!

Finally, we can demonstrate a sort of brute force, rolling "deprecation" of those original, non-patched nodes. First, let's cordon + drain all of them, one-at-a-time, with a 30 second delay in between:

```sh
$ for i in `seq 1 9`; do kubectl cordon k8s-agentpool1-26100436-vmss00000$i && kubectl drain --ignore-daemonsets --delete-emptydir-data --force --grace-period 300 --timeout 900s k8s-agentpool1-26100436-vmss00000$i && sleep 30; done
node/k8s-agentpool1-26100436-vmss000001 cordoned
node/k8s-agentpool1-26100436-vmss000001 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-bwgxq, kube-system/azure-ip-masq-agent-5drs7, kube-system/blobfuse-flexvol-installer-6hdng, kube-system/csi-secrets-store-provider-azure-6222t, kube-system/csi-secrets-store-x42fn, kube-system/kube-proxy-8dwsj
node/k8s-agentpool1-26100436-vmss000001 drained
node/k8s-agentpool1-26100436-vmss000002 cordoned
node/k8s-agentpool1-26100436-vmss000002 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-zd5fh, kube-system/azure-ip-masq-agent-xv8ll, kube-system/blobfuse-flexvol-installer-q9452, kube-system/csi-secrets-store-7zcw4, kube-system/csi-secrets-store-provider-azure-2b6vp, kube-system/kube-proxy-kptk6
node/k8s-agentpool1-26100436-vmss000002 drained
node/k8s-agentpool1-26100436-vmss000003 cordoned
node/k8s-agentpool1-26100436-vmss000003 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-f8xvn, kube-system/azure-ip-masq-agent-qvbt6, kube-system/blobfuse-flexvol-installer-kr2kj, kube-system/csi-secrets-store-provider-azure-cr9b5, kube-system/csi-secrets-store-vwvq4, kube-system/kube-proxy-7c5hj
node/k8s-agentpool1-26100436-vmss000003 drained
node/k8s-agentpool1-26100436-vmss000004 cordoned
node/k8s-agentpool1-26100436-vmss000004 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-jclsb, kube-system/azure-ip-masq-agent-5zxnc, kube-system/blobfuse-flexvol-installer-pn7fs, kube-system/csi-secrets-store-kc74p, kube-system/csi-secrets-store-provider-azure-mp2bs, kube-system/kube-proxy-drsvf
node/k8s-agentpool1-26100436-vmss000004 drained
node/k8s-agentpool1-26100436-vmss000005 cordoned
node/k8s-agentpool1-26100436-vmss000005 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-fcck4, kube-system/azure-ip-masq-agent-2pgdd, kube-system/blobfuse-flexvol-installer-pkdjz, kube-system/csi-secrets-store-24595, kube-system/csi-secrets-store-provider-azure-wvznw, kube-system/kube-proxy-7l8xb
node/k8s-agentpool1-26100436-vmss000005 drained
node/k8s-agentpool1-26100436-vmss000006 cordoned
node/k8s-agentpool1-26100436-vmss000006 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-j7nh9, kube-system/azure-ip-masq-agent-km57d, kube-system/blobfuse-flexvol-installer-7tcc8, kube-system/csi-secrets-store-cmtgb, kube-system/csi-secrets-store-provider-azure-dsxmh, kube-system/kube-proxy-8qscw
node/k8s-agentpool1-26100436-vmss000006 drained
node/k8s-agentpool1-26100436-vmss000007 cordoned
node/k8s-agentpool1-26100436-vmss000007 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-x9c9x, kube-system/azure-ip-masq-agent-5l4w2, kube-system/blobfuse-flexvol-installer-m7tm2, kube-system/csi-secrets-store-b7qqp, kube-system/csi-secrets-store-provider-azure-9898t, kube-system/kube-proxy-ff2n6
node/k8s-agentpool1-26100436-vmss000007 drained
node/k8s-agentpool1-26100436-vmss000008 cordoned
node/k8s-agentpool1-26100436-vmss000008 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-jblk8, kube-system/azure-ip-masq-agent-pk74f, kube-system/blobfuse-flexvol-installer-c5wx8, kube-system/csi-secrets-store-provider-azure-9sgb4, kube-system/csi-secrets-store-xrgwn, kube-system/kube-proxy-rg2qp
node/k8s-agentpool1-26100436-vmss000008 drained
node/k8s-agentpool1-26100436-vmss000009 cordoned
node/k8s-agentpool1-26100436-vmss000009 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/azure-cni-networkmonitor-lbjqw, kube-system/azure-ip-masq-agent-zp582, kube-system/blobfuse-flexvol-installer-zlskb, kube-system/csi-secrets-store-jfsg6, kube-system/csi-secrets-store-provider-azure-jvzv7, kube-system/kube-proxy-b4gl8
evicting pod kube-system/metrics-server-6c8cc7585b-fvm5f
pod/metrics-server-6c8cc7585b-fvm5f evicted
node/k8s-agentpool1-26100436-vmss000009 evicted
```

Note: this particular recipe for "removing 9 nodes from a cluster" is intentionally simplified. There are manifold strategies to do such an operation. In addition, adding 10 (via the `vmss-prototype` helm release) all of the sudden is not at all the right strategy for all cluster scenarios in terms of implementing a "rolling replacement" of "old" with "new" nodes. Hopefully these concrete examples inspire you to implement your own operational gestures appropriate for your environment.

In any event, we should now see that these 9 nodes are no longer actively participating in the cluster:

```sh
$ k get nodes -o wide
NAME                                 STATUS                     ROLES    AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-agentpool1-26100436-vmss000001   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.35    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000002   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.66    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000003   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.97    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000004   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.128   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000005   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.159   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000006   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.190   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000007   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.221   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000008   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.0.252   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss000009   Ready,SchedulingDisabled   agent    165m   v1.20.1   10.240.1.27    <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000a   Ready                      agent    34m    v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000b   Ready                      agent    34m    v1.20.1   10.240.1.88    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000c   Ready                      agent    34m    v1.20.1   10.240.1.119   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000d   Ready                      agent    34m    v1.20.1   10.240.1.150   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000e   Ready                      agent    34m    v1.20.1   10.240.1.181   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000f   Ready                      agent    34m    v1.20.1   10.240.1.212   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000g   Ready                      agent    34m    v1.20.1   10.240.1.243   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000h   Ready                      agent    33m    v1.20.1   10.240.2.18    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000i   Ready                      agent    34m    v1.20.1   10.240.2.49    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000j   Ready                      agent    35m    v1.20.1   10.240.2.80    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000k   Ready                      agent    14m    v1.20.1   10.240.2.111   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-master-26100436-0                Ready                      master   166m   v1.20.1   10.255.255.5   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
```

Which means we can safely delete them:

```sh
$ for i in `seq 1 9`; do az vmss delete-instances --resource-group kubernetes-westus2-17813 --name k8s-agentpool1-26100436-vmss --instance-ids $i --no-wait; done
$ echo $?
0
```

As it takes some time for Azure to delete the instances, and some more time for the node registration database to remove the nodes from service, we won't see this immediately, but eventually:

```sh
$ k get nodes -o wide
NAME                                 STATUS                        ROLES    AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-agentpool1-26100436-vmss00000a   Ready                         agent    47m    v1.20.1   10.240.0.4     <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000b   Ready                         agent    47m    v1.20.1   10.240.1.88    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000c   Ready                         agent    47m    v1.20.1   10.240.1.119   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000d   Ready                         agent    47m    v1.20.1   10.240.1.150   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000e   Ready                         agent    47m    v1.20.1   10.240.1.181   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000f   Ready                         agent    47m    v1.20.1   10.240.1.212   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000g   Ready                         agent    47m    v1.20.1   10.240.1.243   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000h   Ready                         agent    46m    v1.20.1   10.240.2.18    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000i   Ready                         agent    47m    v1.20.1   10.240.2.49    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000j   Ready                         agent    47m    v1.20.1   10.240.2.80    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-agentpool1-26100436-vmss00000k   Ready                         agent    27m    v1.20.1   10.240.2.111   <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.14
k8s-master-26100436-0                Ready                         master   178m   v1.20.1   10.255.255.5   <none>        Ubuntu 18.04.5 LTS   5.4.0-1032-azure   docker://19.3.14
```

We have now replaced our entire set of original nodes running an "old" configuration with fresh, updated nodes. More importantly, we have configured our VMSS so that all new nodes scaled out from this pool will now derive from the updated configuration. This solution is resilient!
