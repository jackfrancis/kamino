# vmss-prototype

`vmss-prototype` takes a snapshot of the OS image from one instance in your VMSS node pool, and then updates the VMSS model definition so that future instances (nodes) use that image snapshot.

This simple concept can dramatically improve node scaling response time and reliability:

1. Pick your best node running in a pool.
2. Make all new nodes like it.

## Example

Below is the canonical way to run vmss-prototype on your cluster using our published Helm Chart:

```bash
$ helm install --repo https://jackfrancis.github.io/kamino/ vmss-prototype \
  update-vmss-model-image-from-instance-0 --namespace default \
  --set kamino.scheduleOnControlPlane=true \
  --set kamino.targetNode=k8s-pool1-12345678-vmss000000
```

## Cluster Configuration Requirements before using

`vmss-prototype` assumes a few things about the way your cluster has been built:

- It expects an Azure cloud provider config file at the path `/etc/kubernetes/azure.json` on the node VM that the job's pod is scheduled onto (in the above example we instruct Helm to create a release, and ultimately a job resource, both named "update-vmss-model-image-from-instance-0").
- If you invoke the `helm install` command using the `--set kamino.scheduleOnControlPlane=true` option, it expects that the control plane nodes respond to the "`kubernetes.io/role: master`" nodeSelector.
  - If you do *not* invoke the `--set kamino.scheduleOnControlPlane=true` option, it expects at least 2 nodes to be running in your cluster, as the `vmss-prototype` pod will not be scheduled onto the target node itself (because the target node is removed from the cluster in order to create a snapshot)
- It expects the targetNode to be a Linux node (no Windows node support).
- It expects that the set of systemd service definitions (kublet, containerd|docker, etc) to be implemented generically with respect to the underlying hostname. In other words, it expects that there are no static references to a very particular hostname string, but instead all local references will derive from a runtime reference equivalent to `$(hostname)`.
- It expects the Kubernetes application layer (i.e., kubelet) to defer to the network stack for IP address information — i.e., it expects no static IP configuration to be present.
- It expects the Azure VMSS definition to have a "DHCP-like" network configuration for instances as they are created; again, no static IP address configurations.
- It expects that when a new VM built with this image snapshot will be pre-configured to run the necessary Kubernetes node runtime (kublet) automatically, and join the cluster without any additional bootstrap scripts. This requirement is owing to the fact that cloud-init and any CustomScriptExtensions attached to the VMSS model definition are removed during the `vmss-prototype` process. These are removed by design, to optimize the node join process by removing unnecessary (all Kubernetes runtime configuration has already been applied) boot cycle friction.

The above details reflect operational configurations produced by a Kubernetes + Azure cluster created with the [AKS Engine](https://github.com/Azure/aks-engine) tool. As of this writing, AKS Engine-created clusters are the only validated, known-working Azure Kubernetes cluster "flavor"; strictly speaking, so long as the above set of cluster configuration requirements are met, any Kubernetes cluster's VMSS nodes running on Azure may take advantage of `vmss-prototype`.

## Why would I want to use vmss-prototype?

Firstly, for an in-depth discussion of the problem domain the kamino project aims to address, please read [this documentation](../../docs/origins.md).

The problems that `vmss-prototype` aims to solve are three-fold:

1. Over time, the "VMSS recipe" that is used to create new VMSS nodes becomes stale, requiring new nodes to perform a series of "catch-up" operations in order to acquire all the new, good stuff (OS patches, security updates, local container image cache that optimizes real-world usage of the VMSS as a container execution surface area) that has been released into the production Linux + Azure + Kubernetes ecosystem since the VMSS was originally defined. This is a problem because those "catch-up" operations take time, and can fail due to network I/O dependencies. We are waiting longer to get new nodes when we need them, and we aren't getting them at all sometimes.
2. In addition, there is a validation problem with respect to introducing "new, updated versions of nodes" generally. How do we confidently know that _a new node recipe will actually work_ before applying that new node recipe in production? The `vmss-prototype` solution solves for this by _using existing, known-working nodes running in the *actual target cluster environment*_ to produce the new node recipe.
3. Finally, a (welcome!) side-effect of (1) priming the node in advance to have all the latest, good stuff already present and (2) optimizing for reliability by assuring known-working outcomes solves the problem "How can I ensure that new nodes come online as quickly as possible when I need them?"

### Remarks About Problem #1 - Get the Latest, Good Stuff

It should be mentioned that one way to partially solve this problem without a tool like `vmss-prototype` would be to ensure that your VMSS model references a _mutable_ OS image release channel (e.g. Canonical Ubuntu 18.04 @ a "latest" version/tag). In such a configuration, the VMSS instances rendered over time would follow the OS updates and patches delivered by your preferred OS distribution.

However, while this solution solves a significant part of the "Get the Latest" imperatives we're discussing, it does not solve for the "Good" part. This is because in such a configuration we are passively accepting a changeset compared to what we know works on older nodes: we have not tested that these new changes are actually Good before introducing them into our production node environment. To use a concrete example: _if_ our OS distribution pushed out a regression that affected the operational performance of a node — let's say, we now notice significant packet loss due to a TCP bug — we do not have a tractable rollback plan. Because we have been passively accepting "latest" throughout the lifecycle of our cluster, we may not know with what underlying OS rev this regression was introduced. When we do discover the "last known-working version", we could then temporarily modify our VMSS configuration to point to it rather than "latest", and then look for all affected nodes, cordon/drain them, and create new ones; and then wait for the regression to be resolved, revert to consuming "latest"; and then wait for the next time a regression is introduced and do this all over again.

Compare the above regression delivery scenario to one in which your VMSS definition points to an _immutable, strongly versioned_ OS image source. In this VMSS configuration, you are able to test and validate a known OS configuration prior to introducing it to production. Also in this VMSS configuration, OS patches and security updates (and unfortunately, sometimes regressions) arrive via back-channel (e.g., `apt-get dist-upgrade`) subscriptions, and require explicit user intervention (e.g., a host OS reboot) in order to apply. As we've stated above, this operational scenario presents a problem: over time, our nodes become more and more stale; more and more "back-channel", manual operations are required in order to build a new node that is fresh with respect to all the latest, good stuff. What the `vmss-prototype` solution allows us to do is to triage the rendering of that operational hygiene in the following way:

- We can focus on applying new changes to the OS on one node only, which scales nicely (the factor is a constant) from an operational perspective.
- Impacts due to the accepance of unintended regressions are isolated to that one node. And in practical fact, if we're able to isolate the regression before re-enabling that node (we assume that most manual OS update gestures will require that we gracefully take the node offline prior to performing updates) we may be able to avoid any production impact altogether. Whether or not we discover the regression due to Kubernetes application layer node validations (which could expose the regressed node to production traffic depending on how we operationally validate nodes), we can quickly mark those sets of OS updates and patches as "non-working" and ensure that our remaining nodes in the cluster "remain stale", so to speak: in this case we have avoided the Latest, _Bad_ Stuff!

We should emphasize that `vmss-prototype` doesn't do any of the mission-critical operational work outlined above! It's an exercise to the user to implement sane operational change management solutions that safely deliver OS layer changes to your nodes over time (though it is a goal of the kamino project to build tooling to help folks build these solutions). How `vmss-prototype` helps is that *if* you run a Kubernetes cluster with VMSS nodes according to an operational workflow resembling the second scenario above, `vmss-prototype` can help you to efficiently distribute node updates across your node pools by updating the VMSS model to ensure that new nodes are always built with the Latest, Good Stuff already include.

We should also emphasize that `vmss-prototype` does not actually perform any of that "node update distribution" itself — again, it's an exercise for the user to implement that according to the unique operational requirements of his or her cluster.

## How does vmss-prototype actually work?

The `vmss-prototype` operation carries out a procedural set of steps, each of which must succeed in order to proceed (there are exceptions in order to implement the entire operation idempotently; those exceptions will be noted). If any one of the steps fails (where appropriate, each step implements retries), the operation will fail. Concretely:

1. Create an Azure API connection with the appropriate privileges needed in order to create resources in the cluster resource group.
2. Validate (1) that the targetNode exists in the cluster, (2) is a VMSS instance, and (3) is in a Ready state.
3. Create a named _Shared Image Gallery_ (SIG) resource in the cluster, if it doesn't already exist. The name of this SIG will be `"SIG_<resource_group>"`, where `<resource_group>` is the name of the resource group that your cluster resources (in particular your VMSS) are installed into. Because the resource group your cluster VMSS is running in does not change, this suffix can be considered a static constant: this SIG will always exist under that name so long as `vmss-prototype` is being used. It's also easy to create idempotently: if it's already there, we just use it; if it isn't, we know this is the first time that `vmss-prototype` has been run in this cluster.
4. Create a named SIG _Image Definition_ within the named SIG created by the above step, if it doesn't already exist. An Image Definition is essentially a named bucket that will contain a bunch of "versioned" images. The name of this SIG Image Definition will be `kamino-<nodepool_name>-vmss-prototype`, where `<nodepool_name>` is the name of the VMSS node pool in your cluster. Similar to how we idempotently create the SIG itself, this Image Definition can be statically, uniquely identified so long as the node pool exists in your cluster.
5. Verify that we have not yet created an Image Definition _version_ (in other words, an actual image) for this VMSS node pool in the last 24 hours. The Image Definition versions are named by date using a format `YYYY.MM.DD`, which means **you can only create one image per day, per VMSS node pool**.
6. Similarly verify that we have not yet created an OS snapshot from the target VMSS instance in the last 24 hours. If we _do have an image with the current day's version_, then we don't fail the operation, but instead assume that we are in a retry context, and skip to step 14 below to build the SIG Image Definition version from the snapshot with today's date. If there is not an image with today's timestamp then we go to the next step:
7. Add a node annotation of `"cluster-autoscaler.kubernetes.io/scale-down-disabled=true"` to the target node, so that if cluster-autoscaler is running in our cluster we prevent it from _deleting that node_ (that's what happens when you scale down), and thus deleting the VMSS instance, while we are taking an OS image snapshot of the instance.
8. Cordon + drain the target node in preparation for taking it offline. If the cordon + drain fails, we will fail the operation _unless we pass in the `--force` option to the `vmss-prototype` tool (see the Helm Chart usage of `kamino.drain.force` below)_.
9. Deallocate the VMSS instance. This is a fancy, Azure-specific way of saying that we release the reservation of the underlying compute hardware running that instance virtual machine. This is a pre-condition to performing a snapshot of the underlying disk.
10. Make a snapshot of the OS disk image attached to the deallocated VMSS instance.
11. *Permanently delete the VMSS instance.* This is due to an [open issue](https://github.com/jackfrancis/kamino/issues/26). Long-term, we aim to solve that issue and simply re-introduce the snapshotted node back into the cluster. In the meanwhile, one operational side-effect of `vmss-prototype` is the loss of one node in the node pool. If you wish to re-add one node after `vmss-prototype` has completed updating the VMSS model, you may use the `--set kamino.newUpdatedNodes=1` option when invoking `helm install`.
12. Uncordon the node to allow Kubernetes to schedule workloads onto it.
13. Remove the `cluster-autoscaler.kubernetes.io/scale-down-disabled` cluster-autoscaler node annotation as we no longer care if this node is chosen for removal by cluster-autoscaler.
14. Build a new SIG Image Definition _version_ (i.e., the actual image we're going to update the VMSS to use) from the recently captured snapshot image. This takes a long time! In our tests we see a 30 GB image (the OS disk size default for many Linux distros) take between 30 minutes and 2 _hours_ to be rendered as a SIG Image Definition version!
15. After the new SIG Image Definition version has been created, we delete the snapshot image as it will no longer be needed for use.
16. We now prune older SIG Image Definition versions (configurable, see the usage of `kamino.imageHistory` in the official Helm Chart docs below).
17. Update the target instance's VMSS model so that its OS image refers to the newly created SIG Image Definition version. This means that the very next instance built with this VMSS will derive from the newly created image. *This update operation does not affect existing instances: The `vmss-prototype` tool does not instruct the VMSS API to perform a "rolling upgrade" to ensure that all instances are running this new OS image! Similarly, `vmss-prototype` **will not** perform a "rolling upgrade" across the other, existing VMSS instances, nor will it create new, replacement instances, and delete old instances!*
18. Update the target instance's cloud-init configuration so that it no longer includes "one-time bootstrap" configuration. Because this instance was _already_ bootstrapped when the cluster was created, we don't need to perform those various prerequisite file system operations: by updating the VMSS's OS image reference to a "post-bootstrapped" image, `vmss-prototype` has made it unnecessary for new instances to perform this cloud-init bootstrap overhead: our new nodes will come online more quickly!
19. Similarly, we remove any VMSS "Extensions" that were used to execute "one-time bootrap executable code" (i.e., all the stuff we execute to turn a vanilla Linux VM into a Kubernetes node running in a cluster), except for any "provenance-identifying" Extensions, e.g. "computeAksLinuxBilling". Similar to the cloud-init savings, `vmss-prototype` allows us to create new instances _already configured to come online immediately as Kubernetes nodes in this cluster!_

That's how it works! Hopefully all that level of detail helps to solidify the value of having regularly, freshly configured nodes across your node pool. Once again:

1. Pick your best node running in a pool.
2. Make all new nodes like it.

## A final note on VMSS instance rolling upgrades

We consider it out of the scope of the `vmss-prototype` tool to reconcile the new VMSS model changes across the VMSS instances and leave it up to the user to do this work, if appropriate. The VMSS itself includes an "Upgrade" option to do a configurable rolling upgrade across instances that are not running the latest model; it's worth emphasizing that this is **not** a Kubernetes-friendly way to update nodes, as the VMSS does not know how to cordon + drain the Kubernetes workloads actively running as container executables on the instances.

It's also worth emphasizing that the problem domain addressed by `vmss-prototype` is not _"Make all nodes the same"_, but is rather _"Update my node recipe so that all future nodes derive from my best, known-working node"_. This solves the practical challenge of ensuring that you get new nodes quickly when you need them. If you have a particular problem that requires your nodes in a pool to be as operationally identical as possible throughout the lifecycle of the cluster, you may use `vmss-prototype` as part of your solution, but gracefully applying VMSS model updates across all nodes is left as an exercise to the user.

## How to use vmss-prototype?

`vmss-prototype` is packaged for use as a Helm Chart, hosted at the `https://jackfrancis.github.io/kamino/` Helm Repository.

The following Helm Chart values are exposed to configure a `vmss-prototype` release:

- `kamino.targetNode` (required to actually create a new prototype updated the VMSS model)
  - e.g., `--set kamino.targetNode=k8s-pool1-12345678-vmss000000`
  - This is the node to derive a "prototype" from. Must exist in your cluster, be in a Ready state, and be backed by a VMSS-created instance. The VMSS (scale set) that this node instance is a part of will be updated as part of the `vmss-prototpe` operation. We recommend you choose a node that has been validated against your operational criteria (e.g., running the latest OS patches and/or security hotfixes). We also recommend that you choose a node that is performing an operational role suitable for being taken temporarily out of service, as the `vmss-prototype` operation will include a cordon + drain against this node in order to shut down the VMSS instance and take a snapshot of the OS disk. If you omit this option, then `vmss-prototype` will not create a new prototype, but will instead report back the status of existing VMSS prototypes built from this tool by looking at all VMSS in the resource group.

- `kamino.scheduleOnControlPlane` (default value is `false`)
  - e.g., `--set kamino.scheduleOnControlPlane=true`
  - Instructs the Kubernetes scheduler to require a control plane VM to execute the pod container on. If you're running a cluster configuration that doesn't have a `/etc/kubernetes/azure.json` with an Azure service principle configuration that permits the creation of resources in the cluster resource group, or if you're running in an MSI (system- or user-assigned identity) configuration which grants only control plane VMs a "Contributor" role assignment (but not worker node VMs), then you must use this. tl;dr this is a configuration which should work for almost all clusters (control plane VMs will *always* have the appropriate privileges in the cluster resource group), but in practice we default to `false` under the assumption that enough folks prefer _not_ to schedule anything on control plane VMs.

- `kamino.newUpdatedNodes` (default value is `0`)
  - e.g., `--set kamino.newUpdatedNodes=1`
  - Immediately add nodes to the cluster in the updated node pool after `vmss-prototype` has successfully updated the VMSS model based on the target node's OS image.

- `kamino.imageHistory` (default value is `3`)
  - e.g., `--set kamino.imageHistory=5`
  - Override the default if you wish to retain more or fewer Shared Image Gallery OS snapshot images in the VMSS-specific SIG Image Definition created by `vmss-prototype`. One SIG per VMSS will be created by `vmss-prototype`; invoking a custom value of `imageHistory` during a run of `vmss-prototype` will inform how many, if any, existing SIG images in that VMSS-specific SIG Image Definition to prune.

- `kamino.drain.gracePeriod` (default value is `300`)
  - e.g., `--set kamino.drain.gracePeriod=60`
  - Override the default if you wish to allow more or less time for the pods running on the node to gracefully exit. This is directly equivalent to the `--grace-period` flag of the `kubectl drain` CLI operation

- `kamino.drain.force` (default value is `false`)
  - e.g., `--set kamino.drain.force=true`
  - Override the default if you wish to force a drain even if the grace period has expired, or if there are non-replicated pods (e.g., not part of a ReplicationController, ReplicaSet [i.e., Deployment], DaemonSet, StatefulSet or Job). This is directly equivalent to the `--force` flag of the `kubectl drain` CLI operation

More documentation on node drain can be found [here in the `kubectl` documentation](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#drain).

- `kamino.logLevel` (default value is `INFO`, options are `DEBUG`, `INFO`, `WARNING`, `ERROR`, and `CRITICAL`)
  - e.g., `--set kamino.logLevel=VERBOSE`
  - Override the default if you wish to see more or less log output in the `vmss-prototype` pod.
