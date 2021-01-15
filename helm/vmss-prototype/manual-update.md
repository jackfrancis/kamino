# Manual Update

This is a low level description of the basic functions of the VMSS-Prototype Pattern (Kamino) system.  This goes into deep details as to what you are doing on the machine.

## Example

Below is the canonical way to run vmss-prototype on your cluster using our published Helm Chart:

```bash
$ helm install --repo https://jackfrancis.github.io/kamino/ \
  update-vmss-model-image-from-instance-0 \
  vmss-prototype \
  --namespace default \
  --set kamino.scheduleOnControlPlane=true \
  --set kamino.targetNode=k8s-pool1-12345678-vmss000000
```

A complete walkthrough of using `vmss-prototype` on a cluster is [here](walkthrough.md).
