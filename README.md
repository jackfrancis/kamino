# Kamino
Kubernetes node clone factory

## Origins

This project is a small but significant feature of the Skyman platform that
is used throughout the Cognitive Services teams within Microsoft.  The overall
platform is built on top of Kubernetes and aks-engine in Azure to run the
large production real-time AI workloads that Microsoft has.

## Managing Node Health and Scaling

There are what I like to call 3 key operations that are needed in a cluster.

### Patching/Updating Nodes
The core need is to apply patches/security fixes/etc to the host nodes in the
cluster as they are approved/released for use.  This is important as otherwise
the host nodes may be left vulnerable to known flaws (either security or just
reliability/performance).

This process is one that is needed for long running clusters.

### Scaling Nodes and Patch Application

In clusters that scale in new nodes at any regular basis, the nodes start out
in the same state that the original image defined for the VMSS was built with.
This means that new nodes need to apply the applicable security patches and
updates that were released since that image was created.  This results in
two things when scaling dynamically:

1) Nodes are doing a lot of work to patch themselves (including needed reboots)
2) Nodes are temporarily vulnerable to any security issues

This is costly in a number of ways.  What the prototype pattern does is enable
those node-level transformations to be saved and already installed on newly
scaled in nodes.

There are some additional benefits but, for example, in our many of cluster,
we often see a dynamic range of hundreds of nodes between the lowest use and
highest use within a given day.  This means that hundreds of nodes would be
scaling in and applying patches every day - putting a large burden on the
patch servers and the network plus adding overhead/reducing useful work those
nodes can do along with the various error paths that could happen.

## The Full Solution

The full solution we had developed consists of basically 3 components:

1) Update/patch the nodes of the clusters (includes graceful rebooting)
2) Determine a new prototype is needed and select the healthy/updated node to become the prototype
3) Using the selected node, generate a new base image for the node pool

### First release is step 3?

The key bit of code we are first producing here is step 3.  Why?

The reason is that step 1 may have already been implemented by people today.
We have our own in the Skyman platform but in any case, the biggest value
is not solving this problem right now.  It will come when we talk about
the full solution.

Step 2 is very much dependent on step 1 - there are bits of data or annotations
that are needed to automatically reason about which node is most suited to
becoming the prototype pattern node.

Step 3 is the part that no one (or no one we know of) has.  This part can
be used, in the worst case, by someone manually selecting the target node.
However, without step 3, the scaling in of new nodes is costly and potentially
a security risk.  Thus, our first release is step 3.

### Will we do more?

Yes - our goal is to bring steps 1 and 2 as pluggable elements such that
each of them could be replaced with their own implementations.  Our goal
is to have a basic reference implementation of all 3 components.

Our hope is that these components are composable and replaceable as needed.
Again, the big push with doing step 3 first is that we feel that is the
most critical and unique component right now.

# Original document

NOTE:  We will edit this to make it more suitable for the Kamino project

# Skyman VMSS "Prototype Pattern"
Moving constants out of the inner loop of node scaling and getting the latest
OS patches pre-installed.

This is a mix of [Prototype Pattern](https://en.wikipedia.org/wiki/Prototype_pattern)
and [Memoization](https://en.wikipedia.org/wiki/Memoization) but I claim it
is easier to think of this as being the [Prototype Pattern](https://en.wikipedia.org/wiki/Prototype_pattern).

## Current VMSS Behavior
The normal VMSS pattern is to use some generic base image for VMSS and apply
the cloud-init and CSE extensions to each instance as they get scaled in.
Basically, performing one-time, application domain-specific bootstrapping
during each VM instance scale in operation.

This introduces problems in that those operations to prepare a node for running
kubernetes workloads is a constant that we do inside the node scaling "loop"
for each node we scale in.  Some of those operations involve network operations
and sometimes code downloads, all of which is paid for on each node instance
as it is scaled in.  Those post-deployment operations are environment-specific
(i.e., VMSS-specific), but they are not instance-specific.

OS patches and updates also need to be installed over time and since new VMs
getting scaled in start with the original image, the number of OS patches to
be installed goes up and thus the time before they are fully patched goes up.
This is a cost to not just our service but the network resources and OS patch
servers.  This gets worse over time as more and more patches are needed by
the image.  We must do this to every instance we scale in.

## The "Prototype Pattern"
The [Prototype Pattern](https://en.wikipedia.org/wiki/Prototype_pattern) is
where we take a known good/working VM instance from the VMSS and make it the
"prototype" upon which all future instances are based.

This is a conceptually simple model - take a good node and basically say, when
we scale, make more just like that one.  One could call them "clones" of
the known good instance.

This provides not only a way to hoist all of the per-node "fixed" operations
outside of the scaling loop, it gives us a clear choice of "this is a working
node" and not one of trying to build an image outside of a cluster and then
test it at deployment time.  The image has, by definition, been tested in the
cluster, has been running useful workloads, and has been fully patched with
the latest OS updates.

### Conceptually Simple

The "normal" mechanism would involved building your own base OS images for your
cluster.  This involves significant investment in knowledge and technology that
those who are running clusters to get their work done do not need or have time
to acquire.  They do not wish to become OS engineers and learn how to build an
OS image with all of the right stuff pre-populated and ready to run in order to
get faster node scaling and the latest patches/updates pre-installed.

Not only is the prototype model conceptually simple, it is far more usable.
Why?  Because we start from a running instance.  The building of an image and
then testing it in a cluster is actually rather complex and long.  This model
is far simpler since it is a known OS disk that was running in the specific
cluster already.

One could look at this as a way to "select what to clone" during scaling.

You could also think of it as "capturing" the node after it finished being
optimized for your cluster.

Note that the prototype model does not obviate the potential usefulness of
building custom base images that are not yet specialized to the environment but
are more specialized than the global default.  However, the prototype model
mechanism gets you the snapshot of not just the specialization at the core
infrastructure level but specialization to this specific cluster instance
and to the specific workloads of the cluster in a single operation.  It also
does so after that specialized image was in operation and tested in the
specific environment it will be used for.

This is memoization of the transform of the node as it goes from its original
image to the specialized image that is actually running.  Those transformations
are consistent across all nodes in the VMSS thus memoizing them just "optimizes"
out that transformation such that future nodes will not need to also execute
them.

### Security Patches

We have been flagged for nodes booting "out of date" and then getting patched.
This is a the big reason this is critical to get into production ASAP.

Yes, performance and reliability are good reasons but the security bit is
the major reason and is why this feature is required and not just nice to have.

### Performance and Reliability Improvements

Since all of the work that currently is in cloud-init and CSE on the nodes
will be hoisted out of the scaling path, all of that time and network cost
will be removed, along with all of the (very rare) failure paths.  When running
at our scale, this makes a big difference.

### Added Benefits

Since this was an actual working node, it likely has a number of docker image
layers on the node already from past workloads.  These are in the docker image
cache and would be part of the prototype new nodes that come on line.  When
those images are useful, this will save even more time and network resources
since the image downloads would be resolved from the local disk cache.

## Implementation Details

The implementation, as it stands now, is per-cluster based.

Part of the reason for this is that the image is very much branded to the
cluster's config.  Some of these are the constants we want to pull out of the
inner "scaling" loop.

It starts with the [Shared Image Gallery](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries)

### Cluser Shared Image Gallery

This is created when we first wish to create a new prototype image.
The gallery will be within the cluster's resource group and contain the
SIG for that cluster.

#### Shared Image Gallery : Image Definition

Within the SIG will be [image definitions](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries#image-definitions)
for each of the VMSS instances for the cluster.  (Or at least each VMSS that
does autoscaling)

#### Shared Image Gallery : Image Definition : Image Versions

Within that image definition will be the image versions for that VMSS base
image.  The versions will be versioned based on YYYY.MM.DD (ex: 2020.10.17)
This fundamentally means no more than 1 new version per day.  Since the cost
of this operation is non-trivial, this is to a reasonable compromise.

Note that the images will be replicated for performance and zone replicated
for reliability (Standard_ZRS).  They don't need to be replicated outside the
region that the cluster is in since they will only ever be used by the cluster.
(They are cluster and vmss specific images)

We do make 3 replicas.  The [recommendation is that for every 600 nodes of VMSS that there is at least 1 replica](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries#scaling).
We currently over-provision a bit by setting this to 3 replicas by default.
Since this is per VMSS, this should be plenty to allow fast and reliable scaling
even for our largest clusters.

### Prototype Node

We will select a good, working node to be the candidate for cloning.  This
selection should include the fact that the node is a known working node and
has all of the patches applied and has run with them.  This makes sure that
we clone a known good example.

This node will be cordoned, drained, and shut down such that a snapshot of
its OS disk can happen.  Once the snapshot is created, the node will be
returned to service within the cluster.

The snapshot will then be used to create the new specific version for the
image definition that matches the VMSS the node came from in the shared image
gallery of the cluster.

*Note: The generation of the image gallery version instance from the snapshot
can take quite a long time.  It takes longer the larger the OS disk is.  This
is outside of my control.*

### VMSS Update

Once we have a new version in the shared image gallery, we can update the VMSS
to point at that new version.  This operation requires that we set a number of
fields in the VMSS such that the disk is used "as is" from the SIG.

Note that the VMSS will claim old nodes are not up-to-date but they logically
are since the changes are just that of applying the common bits to the base
image.  We can update all of the nodes but there is no need to do so right
away.

Our current implementation does not force updates as our goal is really to
optimize the new nodes joining.

We already have the code in the system to process through the VMSS and updating
any nodes that are not on the "current" model within the VMSS.  We just don't
feel it adds any value right now to force this churn in the cluster since all
VMs will become "the same" via the patching system.

### Opt-Out

We have now validated this process any Skyman cluster with the v0.10.1 or later
skyman-cluster-manager chart and is Skyman platform v7 or later, will have this
enabled.  It can be turned off but we highly recommend not to do this as having
this turned off could end up with S360 issues (at a minimum).

### Roll Back

When using these prototype images, we can rather quickly roll back to a prior
image.  Changing to an image already in the shared image gallery is relatively
quick.  Updating all nodes to another image depends on the rate at which nodes
can be taken out of service without impact to customers.  In an outage scenario,
all nodes with the "wrong" image can be restarted at once to pick up the working
image.

The current implementation defaults to keeping the current and prior image in
the gallery.  This should cover most situations.  However, it is just a matter
of cost and shared image gallery capabilities as to the number of versions in
the history.

*Note:  Current implementation does not have automatic roll back - it requires
manual intervention to roll back.  It is, however, as simple as deleting the bad
image version from the shared image gallery image definition.*

## Costs

The only real costs are those of the storage of the disk images.  Under normal
conditions, we will keep the last 2 images (current and prior) in the shared
image gallery such that if we need to, we can delete the newest image and
revert to the prior good image.

The storage costs are going to be the cost for storing in Standard_ZRS storage
(or Standard_LRS for the regions that do not support Standard_ZRS)

See the [billing section of the shared image gallery page](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries#billing).

This cost is per VMSS that we are supporting in the cluster and is rather
minimal.

## Notes:

### Kubernetes Machine ID
There is an identifier that (as far as we can tell) is not used but is normally
unique across machines.  This is the "Machine ID" for a node.  This is separate
from the "System UUID" which is also unique per node.

We are still unsure as to if it matters that the Machine ID is not unique when
VMSS Prototype Pattern based VMs are booted.  I have a [work item](https://dev.azure.com/msasg/Skyman/_workitems/edit/3100432)
to look into this some more in the future.  We have a conceptually simple fix
but it is not trivial to implement and we don't yet have any indication that it
would fix or improve anything.

## Presentation
A [PowerPoint deck is here](https://speechwiki.azurewebsites.net/architecture/Skyman-VMSS-Prototype-Pattern.pptx)

[Recording of the presentation given on November 1st, 2020](https://microsoft-my.sharepoint.com/:v:/p/crpeters/EcyJo1FTuLpNiB1b5_IvayABcvAiypYi8E2LG9Th-7Rjpg)
