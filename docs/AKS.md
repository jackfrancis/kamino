# Kamino on AKS

You can test-drive kamino on your AKS cluster to evaluate the potential value of an optimized OS disk image, with the following, important caveat:

The AKS managed service will eventually overwrite changes that kamino makes to a node pool's underlying VMSS resource:

- kamino-delivered changes to `virtualMachineProfile.storageProfile.imageReference.id` and `virtualMachineProfile.storageProfile.imageReference.resourceGroup` will be reverted the standard AKS OS image maintained by the AKS managed service
- kamino updates to the `virtualMachineProfile.extensionProfile.extensions` array will be reverted

## How to run kamino on your (non-production!) AKS cluster

1. Get the resource group name that your cluster's VMSS are running in. E.g.:

```sh
$ az aks show -n aks-kamino -g aks-kamino | jq -r .nodeResourceGroup
MC_aks-kamino_aks-kamino_westus2
```

2. Get the managed identity resource for your node VMs. E.g.:

```sh
$ az identity list -g MC_aks-kamino_aks-kamino_westus2
[
  {
    "clientId": "<clientId value>",
    "clientSecretUrl": "<clientSecretUrl value>",
    "id": "<id value>",
    "location": "westus2",
    "name": "aks-kamino-agentpool",
    "principalId": "<principalId value>",
    "resourceGroup": "MC_aks-kamino_aks-kamino_westus2",
    "tags": {},
    "tenantId": "<tenantId value>",
    "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
  }
]
```

Now you can give your cluster node pool managed identity resource contributor access to the resource group using the actual value of `principalId` from above (substitute `<principalId value>` below with the actual value):

```sh
$ az role assignment create --assignee <principalId value> --role 'Contributor' --scope /subscriptions/<subscription ID that cluster is in>/resourcegroups/MC_aks-kamino_aks-kamino_westus2
{
  "canDelegate": null,
  "condition": null,
  "conditionVersion": null,
  "description": null,
  "id": "<id value>",
  "name": "<name value>",
  "principalId": "<principalId value>",
  "principalName": "<principalName value>",
  "principalType": "ServicePrincipal",
  "resourceGroup": "MC_aks-kamino_aks-kamino_westus2",
  "roleDefinitionId": "<roleDefinitionId value>",
  "roleDefinitionName": "Contributor",
  "scope": "/subscriptions/<subscription ID that cluster is in>/resourceGroups/MC_aks-kamino_aks-kamino_westus2",
  "type": "Microsoft.Authorization/roleAssignments"
}
```

This additional access granted to your node pool managed identity allows the kamino runtime access to create the necessary infra in your cluster resource group.

Now you can target a particular node running on your cluster, make an OS image snapshot from its OS image, and then use that OS image as a Shared Image Gallery image to build new VMSS VMs from. This will replicate any pre-pulled container images onto any newly scaled out nodes, as well as remove the need to run any startup scripts. This can demonstrably improve reliability and responsiveness of new node scale out operations.

```sh
$ k get nodes
NAME                                STATUS   ROLES   AGE     VERSION
aks-nodepool1-68550425-vmss000000   Ready    agent   5h9m    v1.21.7
aks-nodepool2-35877414-vmss000000   Ready    agent   5h      v1.21.7
aks-nodepool2-35877414-vmss000002   Ready    agent   4h42m   v1.21.7
```

From the above set of nodes let's choose `aks-nodepool2-35877414-vmss000000` from nodepool2 to build a new image from, and to use as a base when building any new nodes in nodepool2:

```sh
$ helm install --repo https://jackfrancis.github.io/kamino/ \
  update-nodepool2-os-image \
  vmss-prototype --namespace default \
  --set kamino.targetNode=aks-nodepool2-35877414-vmss000000
```

The above command will schedule the kamino runtime as a pod on any schedulable node other than the target node, and do the needful work.

Again, at present this solution is not designed for production AKS clusters, as the managed service will overwrite the changes. But have fun testing!

A more detailed walkthrough of how kamino works is [here](../helm/vmss-prototype/walkthrough.md).
