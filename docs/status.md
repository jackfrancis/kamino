# Status

This is a living document to help folks understand where kamino is at in its pre-alpha, baby walker stage.

## Managing Node Health and Scaling

There are what I like to call 3 key operations that are needed in a cluster. As of right now we're focus on generalizing one of those operations as functionality for Kubernetes + Azure.

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
becoming the prototype pattern node.  We have, a mechanism that is a
reasonable base implementation of Step 2 in the code based on the rules
with attributes as we have stated them.

Step 3 is the part that no one (or no one we know of) has.  This part can
be used, in the worst case, by someone manually selecting the target node.
However, without step 3, the scaling in of new nodes is costly and potentially
a security risk.  Thus, our first release is step 3.

### Will we do more?

Yes - our goal is to bring steps 1 and 2 as pluggable elements such that
each of them could be replaced with their own implementations.  Our goal
is to have a basic reference implementation of all 3 components.

With the latest changes to the open source [Kured](https://github.com/weaveworks/kured)
tool, we now have a baseline of step 1 plus our [Kamino auto update](../helm/vmss-prototype/auto-update.md) for
step 2 and 3.

Our hope is that these components are composable and replaceable as needed.
Again, the big push was doing step 3 first in that we felt that was the
most critical and unique component.  Having our step 2 code there and validated
against at least 2 implementations of step 1 (and internal system and now
the public [Kured](https://github.com/weaveworks/kured) project) gives us
confidence that Kamino is a viable first release operational and useful tool.
