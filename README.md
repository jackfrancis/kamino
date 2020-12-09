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

# Documentation

All [documentation can be found here][docs].

[docs]: docs/README.md
[status]: docs/status.md
