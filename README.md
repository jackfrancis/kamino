# Kamino

The kamino project is a collection of Kubernetes cluster tools designed to support and optimize "pools" of nodes. We define a pool as a collection of Kubernetes nodes built according to a common requirement spec. Under the hood, those nodes are implemented as VMs built according to a common recipe and scaled out or in by some cloud provider "VM factory" service (for example, Virtual Machine Scale Sets in Azure, Auto Scaling using AWS).

Put simply: "identical", "peer" nodes that exist _in duplicate_ for the purpose of rapid horizontal scaling.

# Status of Project

The kamino set of tools are currently experimental and pre-alpha. There is no concrete ETA to share in expectation of an alpha or beta release, but we can share a few things about scope and priority:

- Though the problem domain is general, we are focused first of all implementing solutions for Kubernetes on Azure
- Though Kubernetes on Azure has a variety of manifestations, the initial spike will prove out functionality on [AKS Engine](https://github.com/Azure/aks-engine).
- A working helm repo will always reflect the latest set of known-working (again: at present, only Kubernetes clusters running on Azure built with AKS Engine) functionality:
  - https://jackfrancis.github.io/kamino/

More status [here][status].

We encourage folks who are using the above stated, known-working Kubernetes + Azure foundations to experiment and report back any issues, or request additional functionality that will help your existing node set use cases:

- https://github.com/jackfrancis/kamino/issues

# Quickstart

## vmss-prototype

The kamino project publishes a Helm Chart called "vmss-prototype". You may use that Chart to take a snapshot of the OS image from one instance in your VMSS node pool, and then update the VMSS model definition so that future instances (nodes) use that image snapshot. For example:

```bash
$ helm install --repo https://jackfrancis.github.io/kamino/ vmss-prototype \
  update-vmss-model-image-from-instance-0 --namespace default \
  --set kamino.scheduleOnControlPlane=true \
  --set kamino.targetNode=k8s-pool1-12345678-vmss000000
```

The above will create job `update-vmss-model-image-from-instance-0` in the `default` Kubernetes namespace if a few assumptions are true:

- You run the above helm command in an execution context where the `KUBECONFIG` environment variable is set to the kubeconfig file that identifies a privileged connection to the Kubernetes cluster whose node pool you want to update.
- The node `k8s-pool1-12345678-vmss000000` is running in your cluster, backed by an Azure VMSS instance, and is in a Ready state.
- Your Kubernetes + Azure cluster was created by the [AKS Engine](https://github.com/Azure/aks-engine) tool (`vmss-prototype` will work with Kubernetes + Azure generally in the future: for now it is validated as known-working against AKS Engine-created clusters running VMSS node pools).

We suggest the Job name `update-vmss-model-image-from-instance-0` only as a hypothetical example: you may choose any name you wish. Also, the targetNode value `k8s-pool1-12345678-vmss000000` is entirely a hypothetical example: make sure you use a value that correlates with an actual node that was created by an Azure VMSS that you want to update.

If you're not familiar with using `helm` tool to manage Kubernetes resource deployments, lots of good docs are here:

- https://helm.sh/docs/intro/quickstart/

More detailed information on `vmss-prototype` is [here][vmss-prototype].

# Documentation

All [documentation can be found here][docs].

[docs]: docs/README.md
[status]: docs/status.md
[vmss-prototype]: helm/vmss-prototype/README.md
