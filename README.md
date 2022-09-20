# Kamino

The kamino project is a collection of Kubernetes cluster tools designed to support and optimize "pools" of nodes. We define a pool as a collection of Kubernetes nodes built according to a common requirement spec. Under the hood, those nodes are implemented as VMs built according to a common recipe and scaled out or in by some cloud provider "VM factory" service (for example, Virtual Machine Scale Sets in Azure, Auto Scaling using AWS).

Put simply: "identical", "peer" nodes that exist _in duplicate_ for the purpose of rapid horizontal scaling.

# Status of Project

The kamino set of tools are currently approaching a v1.0 stable release, tested against Kubernetes running on Azure with VMSS-backed node pools, on clusters built with the [AKS Engine](https://github.com/Azure/aks-engine) tool.

More status [here][status].

We encourage folks who are using the above stated, known-working Kubernetes + Azure foundations to experiment and report back any issues, or request additional functionality that will help your existing node set use cases:

- https://github.com/jackfrancis/kamino/issues

# Quickstart

## vmss-prototype

The kamino project publishes a Helm Chart called "vmss-prototype". You may use that Chart to take a snapshot of the OS image from one instance in your VMSS node pool, and then update the VMSS model definition so that future instances (nodes) use that image snapshot. For example:

```bash
$ helm install --repo https://jackfrancis.github.io/kamino/ \
  update-vmss-model-image-from-instance-0 \
  vmss-prototype --namespace default \
  --set kamino.scheduleOnControlPlane=true \
  --set kamino.targetNode=k8s-pool1-12345678-vmss000000
```

The above will create a helm release `update-vmss-model-image-from-instance-0`, which will create a job with the same name in the `default` Kubernetes namespace if a few assumptions are true:

- You run the above helm command in an execution context where the `KUBECONFIG` environment variable is set to the kubeconfig file that identifies a privileged connection to the Kubernetes cluster whose node pool you want to update.
- The node `k8s-pool1-12345678-vmss000000` is running in your cluster, backed by an Azure VMSS instance, and is in a Ready state.

We use the helm release name `update-vmss-model-image-from-instance-0` only as a hypothetical example: you may choose any name you wish. Also, the targetNode value `k8s-pool1-12345678-vmss000000` is entirely a hypothetical example: make sure you use a value that correlates with an actual node that was created by an Azure VMSS that you want to update.

If you're not familiar with using `helm` tool to manage Kubernetes resource deployments, lots of good docs are here:

- https://helm.sh/docs/intro/quickstart/

A complete walkthrough of using `vmss-prototype` on a cluster is [here][vmss-prototype-walkthrough].

More detailed information on `vmss-prototype` is [here][vmss-prototype].

# Documentation

All [documentation can be found here][docs].

[docs]: docs/README.md
[status]: docs/status.md
[vmss-prototype-walkthrough]: helm/vmss-prototype/walkthrough.md
[vmss-prototype]: helm/vmss-prototype/README.md
