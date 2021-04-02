# vmss-prototype

`vmss-prototype` takes a snapshot of the OS image from one instance in your VMSS node pool, and then updates the VMSS model definition so that future instances (nodes) use that image snapshot.

This simple concept can dramatically improve node scaling response time, security, and reliability:

1. Pick your best node running in a pool.
2. Make all new nodes like it.

## Examples

1. A [low level walkthrough of this being done manually](manual-update.md).
2. A [higher level walkthrough of this being done automatically](auto-update.md)

## Cluster Configuration Requirements before using

`vmss-prototype` assumes a few things about the way your cluster has been built:

- It expects an Azure cloud provider config file at the path `/etc/kubernetes/azure.json` on the node VM that the job's pod is scheduled onto (in the above example we instruct Helm to create a release, and ultimately a job resource, both named "update-vmss-model-image-from-instance-0").
- If you invoke the `helm install` command using the `--set kamino.scheduleOnControlPlane=true` option, it expects that the control plane nodes respond to the "`kubernetes.io/role: master`" nodeSelector.
  - If you do *not* invoke the `--set kamino.scheduleOnControlPlane=true` option, it expects at least 2 nodes to be running in your cluster, as the `vmss-prototype` pod will not be scheduled onto the target node itself (because the target node is removed from the cluster in order to create a snapshot)
- It expects the targetNode to be a Linux node (no Windows node support).
- It expects that the set of systemd service definitions (kublet, containerd|docker, etc) to be implemented generically with respect to the underlying hostname. In other words, it expects that there are no static references to a very particular hostname string, but instead all local references will derive from a runtime reference equivalent to `$(hostname)`.
- It expects the Kubernetes application layer (i.e., kubelet) to defer to the network stack for IP address information — i.e., it expects no static IP configuration to be present.
- It expects the Azure VMSS definition to have a "DHCP-like" network configuration for instances as they are created; again, no static IP address configurations.
- It expects that when a new VM built with this image snapshot will be able to boot and run the necessary Kubernetes node runtime (kublet) automatically, and join the cluster without any additional bootstrap scripts.  This requirement is easily achieved by the fact that the VM wishes to be able to be rebooted/restarted and return to functioning in the cluster.  We depend on this such that cloud-init and any CustomScriptExtensions attached to the VMSS model definition can be elided (removed) during the `vmss-prototype` process. These are removed by design, to optimize the node join process by removing unnecessary (all Kubernetes runtime configuration has already been applied) boot cycle friction and failure points.

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
5. Verify that we have not yet created an Image Definition _version_ (in other words, an actual image) for this VMSS node pool in the last 24 hours. The Image Definition versions are named by date using a format `YYYY.MM.DD`, which means **you can only create one new image per day, per VMSS node pool**.
6. Similarly verify that we have not yet created an OS snapshot from the target VMSS instance in the last 24 hours. If we _do have an image with the current day's version_, then we don't fail the operation, but instead assume that we are in a retry context, and skip to step 14 below to build the SIG Image Definition version from the snapshot with today's date. If there is not an image with today's timestamp then we go to the next step:
7. Add a node annotation of `"cluster-autoscaler.kubernetes.io/scale-down-disabled=true"` to the target node, so that if cluster-autoscaler is running in our cluster we prevent it from _deleting that node_ (that's what happens when you scale down), and thus deleting the VMSS instance, while we are taking an OS image snapshot of the instance.
8. Cordon + drain the target node in preparation for taking it offline. If the cordon + drain fails, we will fail the operation _unless we pass in the `--force` option to the `vmss-prototype` tool (see the Helm Chart usage of `kamino.drain.force` below)_.
9. Deallocate the VMSS instance. This is a fancy, Azure-specific way of saying that we release the reservation of the underlying compute hardware running that instance virtual machine. This is a pre-condition to performing a snapshot of the underlying disk.
10. Make a snapshot of the OS disk image attached to the deallocated VMSS instance.
11. Restart the node's VMSS instance that we just grabbed a snapshot of.
12. Uncordon the node to allow Kubernetes to schedule workloads onto it.
13. Remove the `cluster-autoscaler.kubernetes.io/scale-down-disabled` cluster-autoscaler node annotation as we no longer care if this node is chosen for removal by cluster-autoscaler.
14. Build a new SIG Image Definition _version_ (i.e., the actual image we're going to update the VMSS to use) from the recently captured snapshot image. This takes a long time! In our tests we see a 30 GB image (the OS disk size default for many Linux distros) take between 30 minutes and 2 _hours_ to be rendered as a SIG Image Definition version!
15. After the new SIG Image Definition version has been created, we delete the snapshot image as it will no longer be needed.
16. We now prune older SIG Image Definition versions (configurable, see the usage of `kamino.imageHistory` in the official Helm Chart docs below).
17. Update the target instance's VMSS model so that its OS image refers to the newly created SIG Image Definition version. This means that the very next instance built with this VMSS will derive from the newly created image. *This update operation does not affect existing instances: The `vmss-prototype` tool does not instruct the VMSS API to perform a "rolling upgrade" to ensure that all instances are running this new OS image! Similarly, `vmss-prototype` **will not** perform a "rolling upgrade" across the other, existing VMSS instances, nor will it create new, replacement instances, or delete old instances!*
18. Update the target instance's cloud-init configuration so that it no longer includes "one-time bootstrap" configuration. Because this instance was _already_ bootstrapped when the cluster was created, we don't need to perform those various prerequisite file system operations: by updating the VMSS's OS image reference to a "post-bootstrapped" image, `vmss-prototype` has made it unnecessary for new instances to perform this cloud-init bootstrap overhead: our new nodes will come online more quickly!
19. Similarly, we remove any VMSS "Extensions" that were used to execute "one-time bootrap executable code" (i.e., all the stuff we execute to turn a vanilla Linux VM into a Kubernetes node running in a cluster), except for any "provenance-identifying" Extensions, e.g. "computeAksLinuxBilling". Similar to the cloud-init savings, `vmss-prototype` allows us to create new instances _already configured to come online immediately as Kubernetes nodes in this cluster!_

That's how it works! Hopefully all that level of detail helps to solidify the value of having regularly, freshly configured nodes across your node pool. Once again:

1. Pick your best node running in a pool.  (See next section for automation of that step)
2. Make all new nodes like it.

## How does vmss-prototype auto-update work?

The auto-update process is a way to automatically determine if an update to the prototype image is needed and what node should be used (and can be used) as the source for the new image.

This process is designed to be able to be automatically run via something like kubernetes cronjob, where most of the time it does nothing as nothing is needed or nothing can be done (not valid candidate nodes for new images).

This also depends on some tool to provide information about the nodes in the form of annotations such that we can tell which nodes are potential candidates due to new OS patches having been installed and that they are not pending a reboot/restart.

These two annotations are defined as the `last-patch` annotation and the `pending-reboot` annotation.  The `vmss-prototype` system can be told what these annotations are such that we can integrate with different node reboot systems.  There is a [proposed change](https://github.com/weaveworks/kured/pull/296) for [kured](https://github.com/weaveworks/kured) that will provide this functionality.

The `last-patch` annotation has, as its value, an [RFC 3339](https://www.ietf.org/rfc/rfc3339.txt) timestamp string in it that indicates when the last OS patch was applied.

The process goes as follows for each VMSS in the cluster or the VMSS specified as the target VMSS:

1. Get the current version of the prototype image for the VMSS in question.  There may be none (thus version 0) or some existing version that is encoded as a `yyyy.mm.dd` version identifier for the Azure Shared Image Gallery
2. Get information about all the nodes in the cluster, including status, annotations, etc.
3. For each node complete the following checks.  If any check fails, that node is ignored as a potential candidate.  I
    1. is the node part of the target VMSS?  (Ignored if not)
    2. is the node running the auto-update process?  (Ignored if it is)
    3. does the node match one of the (optional) list of node names to be ignored?  (Ignored if it is)
    4. is the node "unschedulable"?  (Ignored if it is)
    5. does the node have any of the (optional) ignore node annotations?  (Ignored if it does)
    6. does the node have the `pending-reboot` annotation?  (Ignored if it does)
    7. does the node have the `last-patch` annotation?  (Ignored if it does not)
    8. is the value of the `last-patch` annotation valid?  (Ignored if it is not)
    9. is the `last-patch` annotation a newer date (aka version) compared to the current image version?  (Ignored if it is not)
    10. is the node in 'Ready' state?  (Ignored if it is not)
    11. has the node been continuously in 'Ready' state for at least (configurable) 1 hour?  (Ignored if it has not)
    12. Add nodes that pass the above checks to the list of candidates.
4. If there are not enough candidates, we have nothing to do for this VMSS.  The default is that 1 candidate would be sufficient.
5. From the list of candidates, pick the one that has shown the longest stability of execution.  (We picked some minimum stable time earlier)
6. Using that candidate, start the update process [described above](#how-does-vmss-prototype-actually-work).
7. Repeat from #1 above for the next VMSS pool
8. Wait for all the triggered update processes to complete.
9. Report the now current status of the prototype images.

The magic here is the `last-patch` annotation that tools that are responsible for patching OS nodes would set automatically.  With such as setup, one can just have the auto-update process run as a cronjob and automatically pick notice and build/deploy new prototype images for the VMSS.

Note that we directly run the "manual" update process as part of the automatic process.  Thus, a manual update produces exactly the same results as an automatic update would.

_Future feature - a way to force a new image if there has not been a new OS patch.  We have such a system in the platform where this has been brought from but that has some dependencies on additional health and age monitoring that is not available generically._


## A final note on VMSS instance rolling upgrades

We consider it out of the scope of the `vmss-prototype` tool to reconcile the new VMSS model changes across the VMSS instances and leave it up to the user to do this work, if appropriate. The VMSS itself includes an "Upgrade" option to do a configurable rolling upgrade across instances that are not running the latest model; it's worth emphasizing that this is **not** a Kubernetes-friendly way to update nodes, as the VMSS does not know how to cordon + drain the Kubernetes workloads actively running as container executables on the instances.

It's also worth emphasizing that the problem domain addressed by `vmss-prototype` is not _"Make all nodes the same"_, but is rather _"Update my node recipe so that all future nodes derive from my best, known-working node"_. This solves the practical challenge of ensuring that you get new nodes quickly when you need them. If you have a particular problem that requires your nodes in a pool to be as operationally identical as possible throughout the lifecycle of the cluster, you may use `vmss-prototype` as part of your solution, but gracefully applying VMSS model updates across all nodes is left as an exercise to the user.

## How to use vmss-prototype?

`vmss-prototype` is packaged for use as a Helm Chart, hosted at the `https://jackfrancis.github.io/kamino/` Helm Repository.

The following Helm Chart values are exposed to configure a `vmss-prototype` release.  See [the values.yaml file](values.yaml) for details and defaults.

### Common values

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
  - e.g., `--set kamino.logLevel=DEBUG`
  - Override the default if you wish to see more or less log output in the `vmss-prototype` pod.

### Automatic node selection

Kamino can follow some rules for automatic node selection.  These are the parameters for the helm chart (in addition to the above) to enable this.

The automatic mode can also be enabled as a cronjob (periodic job) that will look to apply the automated processes without manual deployment each time.  This process can then be a fully lights-out operation of Kamino as it automatically detects when a new prototype image is needed (based on parameters provided) and produces it.

- `kamino.targetVMSS` (required to run in automatic mode)
  - A value of `ALL` will automatically scan for all VMSS pools
    - e.g., `--set kamino.targetVMSS=ALL`
  - A value of the VMSS name.  This is the name of the VMSS without the node-specific identifier appended.  For example, `k8s-pool1-12345678-vmss` would be the VMSS that contains nodes such as `k8s-pool1-12345678-vmss000000`
    - e.g., `--set kamino.targetVMSS=k8s-pool1-12345678-vmss`

- `kamino.auto.lastPatchAnnotation` (required)
  - This defines the name of the annotation on the nodes that holds an RFC3339 timestamp of when it last applied an OS patch.  If this annotation is missing, it is assumed the node has not applied an OS patch yet.
    - e.g., `--set kamino.auto.lastPatchAnnotation=LatestOSPatch`

- `kamino.auto.pendingRebootAnnotation` (required ??)
  - This annotation on a node that indicates that the node is in need of reboot for some reason (pending OS patch or other servicing).  Nodes with this annotation are not considered as a viable candidate for making an image.
    - e.g., `--set kamino.auto.pendingRebootAnnotation=RebootPending`
  - Note that setting this to some annotation that never exists causes the system to not filter out any nodes due to this constraint.

- `kamino.auto.minimumReadyTime` (default 1h)
  - This is the minimum time a node must have been in constant "ready" state for it to be considered a potential candidate as the prototype.
  - Values are logically in seconds unless a modifier is used.  For example:
    - `--set kamino.auto.minimumReadyTime=3` --> 3 seconds
    - `--set kamino.auto.minimumReadyTime=3s` --> 3 seconds
    - `--set kamino.auto.minimumReadyTime=3m` --> 3 minutes
    - `--set kamino.auto.minimumReadyTime=3h` --> 3 hours
    - `--set kamino.auto.minimumReadyTime=3d` --> 3 days
  - It is recommended to not have this value too low as this determines how long a node must have been operating before we consider it healthy enough to build future nodes from it.

- `kamino.auto.minimumCandidates` (default 1)
  - This is the minimum number of valid candidates before one is selected.  Must be at least 1 (since you can't selected from a candidate pool of size 0)
    - e.g., `--set kamino.auto.minimumCandidates=5`
  - This is another way to validate the new nodes before committing to using them.  In large clusters, one may wish to see some number of patched and updated nodes successfully running before accpeting that one of the updated nodes is a potential candidate to be the prototype.

- `kamino.auto.dryRun` (optional - defaults to false)
  - If set to true, the auto-update process will only show what choices it made but not actually execute the update process.

- `kamino.auto.cronjob.enabled` (optional - defaults to false)
  - When set to true, will run auto-update job on a periodic basis.  This requires that you use the `kamino.targetVMSS` setting since cronjobs only make sense in automatic mode.
  - This is how we recommend running Kamino

- `kamino.auto.cronjob.schedule` (optional - defaults to "`42 0 * * *`")
  - This value only has meaning if cronjob is enabled
  - Format of this value is [based on UNIX cron syntax](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#cron-schedule-syntax)
    - Our default value is "Daily, 42 minutes after midnight"
    - You can use web tools like [crontab.guru](https://crontab.guru/) to help generate crontab schedule expressions
  - Running this daily will result in only updating the image when there is a suitable candidate to become the new image.
    - This is how you can have all of this running "lights out"

### Manual node selection

When running lower level, you can manually select the node that will be used as the prototype.  Internally, this is what the automatic node selection runs after selecting the node.

- `kamino.targetNode` (required to run in manual mode)
  - e.g., `--set kamino.targetNode=k8s-pool1-12345678-vmss000000`
  - This is the node to derive a "prototype" from. Must exist in your cluster, be in a Ready state, and be backed by a VMSS-created instance. The VMSS (scale set) that this node instance is a part of will be updated as part of the `vmss-prototpe` operation. We recommend you choose a node that has been validated against your operational criteria (e.g., running the latest OS patches and/or security hotfixes). We also recommend that you choose a node that is performing an operational role suitable for being taken temporarily out of service, as the `vmss-prototype` operation will include a cordon + drain against this node in order to shut down the VMSS instance and take a snapshot of the OS disk. If you omit this option, then `vmss-prototype` will not create a new prototype, but will instead report back the status of existing VMSS prototypes built from this tool by looking at all VMSS in the resource group.

### Status operation

If not given a manual node selection or an automatic node selection operation, the chart defaults to just collecting the status of the `vmss-prototype` images and VMSS pools in the cluster and renders that into the logs.
