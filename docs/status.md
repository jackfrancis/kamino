# Status

This is a living document to help folks understand the status of the kamino project.
## Release Status

A complete, automated solution for optimizing node OS updates over time is
tested as working, and will form the basis of an upcoming v1.0.0 release.

The ETA of a v1.0.0 release is June 2021.

## Functional Status

The following functionality is tested and stable on Kubernetes + Azure:

- Update the "node recipe" (in Azure we refer to this as the "VMSS Prototype")
to an OS image snapshot of the most recently rebooted (a proxy for recently
patched), working node VM.
  - The tested component to enforce node reboots is [kured](https://github.com/weaveworks/kured).
  You must use version 1.7.0 or later, which supports node annotations, used
  by kamino's `vmss-prototype` to determine when nodes were last rebooted.
- Update the Azure VMSS definition to remove cloud-init and script extensions,
as we assume those were attached to the VMSS in order to perform an initial
bootstrap of the Kubernetes node (download required components, configure
for Kubernetes, etc), and are no longer required to execute.
- Run all of the above on as a Kubernetes CronJob, with the ability to update
the VMSS image reference as frequently as once per day to optimize highly
dynamic clusters.

## Kubernetes + Azure support

The kamino scenarios are regularly tested against Kubernetes + Azure clusters
using VMSS nodes, built with AKS Engine. Custom-built Kubernetes + Azure
solutions may work as well, so long as the following is true:

- The clusters are using VMSS to build nodes pools of "functionally identical"
sets of nodes
- VMSS is not configured to "auto rollout" VMSS model updates — this would
result in an unnecessary, non-graceful update of _all_ nodes in that VMSS every
time that kamino's `vmss-prototype` updated the OS image. `vmss-prototype` is
not designed to solve the problem of "make all my nodes exactly the same", but
rather it solves the problem "make the _next node_ I build like my most
recently patched, stable node".

## FAQ

### Does kamino support cluster-api + Azure (capz)

At this time, kamino does not have working solutions for capz. There are a
few considerations before we can start experimenting with capz:

- Integrate with cluster-api's support for "VM Sets" (`MachinePool`); or
- Integrate with cluster-api's base VM support (`Machine`)
- Address the kubeadm surface area, which bootstraps nodes differently than
the Azure + Kubernetes scenarios described above.
