# Manual Update

The simplest way to use `vmss-protoype` is to perform an ad hoc, one-time update of the VMSS OS image by choosing a single node (it must be a node built with VMSS) running on your cluster to take an OS image snapshot from.
## Example

Below is the canonical way to run vmss-prototype on your cluster using our published Helm Chart. To manually choose the node to use, and to do a one-time `vmss-prototype` operation, use the `targetNode` helm value:

```bash
$ helm install --repo https://jackfrancis.github.io/kamino/ \
  update-vmss-model-image-from-instance-0 \
  vmss-prototype \
  --namespace default \
  --set kamino.scheduleOnControlPlane=true \
  --set kamino.targetNode=k8s-pool1-12345678-vmss000000
```

A complete walkthrough of using `vmss-prototype` on a cluster is [here](walkthrough.md).
