## Origins

The set of tooling in the kamino project began as a small but significant feature of an internal Microsoft platform called Skyman, built to support various highly available, highly dynamic Cognitive Services operations inside Azure and Microsoft.  Skyman is built on top of Kubernetes and Azure and runs many large production, real-time AI workloads.

The following documents some of the conceptual and practical thinking from that Skyman feature work. It is useful because it describes the design foundations that the kamino project will inherit.

# Kubernetes node "Prototype Pattern"

In practice, we want to move "operational constants" out of the inner loop of real-time node scaling, in order to:

- avoid having to "re-configure" the OS for Kubernetes (e.g., re-plumb systemd)
- get new nodes with OS patches already pre-installed
- get new ndoes with common container images pre-pulled (a pre-warmed container cache)

Conceptually, we borrow from both the [Prototype Pattern](https://en.wikipedia.org/wiki/Prototype_pattern) and from [Memoization](https://en.wikipedia.org/wiki/Memoization); but, because we are dealing with higher order abstractions like production distributed systems, it is arguably the most correct to say that our solutions follow the [Prototype Pattern](https://en.wikipedia.org/wiki/Prototype_pattern).

## Current VMSS Behavior

The following comments on VMSS are specific to Azure. It's appropriate to go into some of that detail in order to describe the actual history; we leave it as an exercise for the reader to generalize the "VMSS" solution to "any VM factory that builds VMs from a common recipe".

The normal VMSS pattern is to use some *generic base image* for VMSS and apply the cloud-init and shell script extensions (by this we mean any configurable, concrete executable code tightly coupled to the VM bootstrap process) to each instance as they are created and join the cluster as a Kubernetes node. Basically, performing one-time, application domain-specific bootstrapping during each VM instance scale out operation.

This introduces problems in that those node bootstrap operations are a constant that we do inside the node scaling "loop" for each node we create.  Some of those operations involve network operations, for example to download pre-requisite code and/or configuration, all of which is paid for _on each node instance_ as it is scaled in.  Those operations are environment-specific (i.e., specific to the entire Virtual Machine Scale Set resource definition), but they are not instance-specific.

OS patches and updates also need to be installed over the lifecyle of the nodes running in the cluster. Over time, newly introduced VMs (as a result of node scale out operations) will continue to be built with the original *generic base image* (according to the specification in the Virtual Machine Scale Set resource definition). In practice, this means that the set of OS patches and updates not originally included in that *generic base image* will increase with time. And in turn, this means with the progress of time, the cost to build new nodes will increase as it includes a continually expanding set of OS patches and updates not already present when that VM comes online. This is an ever increasing cost to not just our service (cluster scale out events take longer as the cluster ages), but also to the network resources and OS patch servers which have to continually accommodate more and more load from our environment as it ages.

## The "Prototype Pattern"

Our usage of the [Prototype Pattern](https://en.wikipedia.org/wiki/Prototype_pattern) is to take a known good/working VM instance from the VMSS and make it the "prototype" upon which all future instances are based.

This is a conceptually simple model - take a good node and basically say, when we scale, make more just like that one.  One could call them "clones" of the known good instance.

This provides not only a way to hoist all of the per-node "fixed" operations outside of the scaling loop, but compared to building an image in a staging environment, and testing nodes in a staging cluster we now have a definitive process by which to build nodes that we know actually work.  The image has, by definition, been tested in the cluster, has been running useful workloads, and has been fully patched with the latest OS updates.

### Conceptually Simple

The "normal" mechanism would involved building your own base OS images for your cluster.  This involves significant investment in knowledge and cloud vendor-specific technology that Kubernetes clusters operators do not necessarily want or have time
to acquire.  They may not wish to become cloud vendor-specific OS engineers in order to learn how to build an OS image with all the right stuff pre-populated to accommodate faster node scaling with the latest OS patches and updates already included.

Not only is the prototype model conceptually simple, it is far more usable. Why?  Because we start from a running instance.  The building of an image and then testing it in a cluster is actually rather complex and long.  This model is far simpler since it is a known OS disk that was running in the specific cluster already.

One could look at this as a way to "select what to clone" during scaling.

You could also think of it as "capturing" the node after it finished being optimized for your cluster.

Note that the prototype model does not obviate the potential usefulness of building custom base images to use when you first create your cluster. These custom base images are not yet specialized to the environment, but will be more specialized than the global default, and may be a preferable workflow to optimize cluster bootstrapping.  However, the prototype model
mechanism gets you the snapshot of not just the specialization at the core infrastructure level but specialization to this specific cluster instance and to the specific workloads of the cluster in a single operation.  It also
does so after that specialized image was in operation and tested in the specific environment it will be used for. In other words: the prototype model gives us a path to accommodate the maintenance of nodes running a base OS image, or a pre-customized OS image.

In practice, as the node image continually transforms from its original to a more specialized image based on what is actually running and working at a particular time we are memoizing the node image for optimal re-use (copying) by all future nodes running in the node set. Because these transformations are consistent across all nodes (VMs) in the VMSS, we can follow this memoization pattern.

### Security Patches

We have been flagged for nodes booting "out of date" and then getting patched. This was a big driver to building a solution quickly. Performance and reliability are sufficient reasons but the security story is the major reason and is why this feature is required and not just nice to have.

### Performance and Reliability Improvements

Since all of the work that is currently in cloud-init and and shell script Extensions on the VMs will be hoisted out of the scaling path, all of that time and network cost will be removed, along with all of the (very rare) failure paths.  When running at scale, this makes a big difference.

### Added Benefits

Since this was an actual working node, it likely has a number of docker image layers on the node already from past workloads.  These are in the docker image cache and would be part of the prototype for new nodes that come on line.  When those images are useful, this will save even more time and network resources since the image downloads would be resolved from the local disk cache.

## Implementation Details

The implementation, as it stands now, is per-cluster based.

Part of the reason for this is that the image is very much branded to the cluster's config.  Some of these are the constants we want to pull out of the inner "scaling" loop.

We use the Azure [Shared Image Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries) service to host our protoype OS images in the same resource group that contains the cluster resources (VMSS, disk, etc).

### Per-Cluster Shared Image Gallery

This is created when we first wish to create a new prototype image. The gallery will be within the cluster's resource group and contain the SIG for that cluster.

#### Shared Image Gallery : Image Definition

Within the SIG will be [image definitions](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries#image-definitions) for each of the VMSS instances for the cluster. (Or at least each VMSS that
serves autoscaling nodes pools).

#### Shared Image Gallery : Image Definition : Image Versions

Within that image definition will be the image versions for that VMSS base image.  The versions will be versioned based on YYYY.MM.DD (ex: 2020.10.17). This fundamentally means no more than 1 new version per day.  Since the cost of this operation is non-trivial, this is a reasonable compromise.

Note that the images will be replicated for performance and zone replicated for reliability (Standard_ZRS).  They don't need to be replicated outside the region that the cluster is in since they will only ever be used by the cluster. (They are cluster and vmss specific images)

We do make 3 replicas.  The [recommendation is that for every 600 nodes of VMSS that there is at least 1 replica](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries#scaling). We currently over-provision a bit by setting this to 3 replicas by default. Since this is per VMSS, this should be enough replicas to allow fast and reliable scaling even for our largest clusters.

### Prototype Node

We will select a good, working node to be the candidate for cloning.  This selection should include the fact that the node is a known working node and has all of the patches applied and has run with them.  This makes sure that we clone a known good example.

This node will be cordoned, drained, and shut down such that a snapshot of its OS disk can happen.  Once the snapshot is created, the node will be returned to service within the cluster.

The snapshot will then be used to create the new specific version for the image definition that matches the VMSS the node came from in the shared image gallery of the cluster.

*Note: The generation of the image gallery version instance from the snapshot can take quite a long time.  It takes longer the larger the OS disk is. This is a known limitation of the Azure Shared Image Gallery service.*

### VMSS Update

Once we have a new version in the shared image gallery, we can update the VMSS model to use this new image.  This operation requires that we set a number of fields in the VMSS such that the disk is used "as is" from the SIG.

Note that the VMSS will claim old nodes are not up-to-date but they logically are since the changes are just that of applying the common bits to the base image.  We can update all of the nodes but there is no need to do so right away.

Our current implementation does not force updates as our goal is really to optimize _the new nodes_ that will next join the cluster.

We can produce functionality to process through the VMSS and updating any nodes that are not on the "current" model within the VMSS.  We just don't feel it adds any value right now to force this churn in the cluster since all VMs will eventually become "the same" over time as new nodes are removed and added during normal autoscaling operations.

### Roll Back

When using these prototype images, we can rather quickly roll back to a prior image.  Changing to an image already in the shared image gallery is relatively quick.  Updating all nodes to another image depends on the rate at which nodes can be taken out of service without impact to customers.  In an outage scenario, all nodes with the "wrong" image can be restarted at once to pick up the working image.

The current implementation defaults to keeping the current and prior image in the gallery.  This should cover most situations.  However, it is just a matter of cost and shared image gallery capabilities as to the number of versions in the history.

*Note:  Current implementation does not have automatic roll back - it requires manual intervention to roll back.  It is, however, as simple as deleting the bad image version from the shared image gallery image definition.*

## Costs

The only real costs are those of the storage of the disk images.  Under normal conditions, we will keep the last 2 images (current and prior) in the shared image gallery such that if we need to, we can delete the newest image and revert to the prior good image.

The storage costs are going to be the cost for storing in Standard_ZRS storage (or Standard_LRS for the regions that do not support Standard_ZRS)

See the [billing section of the shared image gallery page](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries#billing).

This cost is per VMSS that we are supporting in the cluster and is rather minimal.

## Notes:

### Kubernetes Machine ID
There is an identifier that (as far as we can tell) is not used but is normally unique across machines.  This is the "Machine ID" for a node.  This is separate from the "System UUID" which is also unique per node.

We are still unsure as to if it matters that the Machine ID is not unique when VMSS Prototype Pattern based VMs are booted.  We have an [open issue](https://github.com/jackfrancis/kamino/issues/22) to look into this some more in the future.  We have a conceptually simple fix but it is not trivial to implement and we don't yet have any indication that it would fix or improve anything.
