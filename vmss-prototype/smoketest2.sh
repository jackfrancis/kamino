#!/bin/bash -e

MY_ACR=skyman.azurecr.io
MY_REPOSITORY=scratch/kamino/vmss-prototype
MY_TAG=experimental.msinz

az acr login -n ${MY_ACR}

IMAGE_TAG=${MY_ACR}/${MY_REPOSITORY}:${MY_TAG}

docker build . -t ${IMAGE_TAG}

docker run --rm -i -t ${IMAGE_TAG} --help

docker push ${IMAGE_TAG}

# The helm binary - I use helm3 as the name as we had to support both in the past
HELM3=helm3

# Get rid of any prior version (just in case)
${HELM3} delete smoke-test 2>/dev/null >/dev/null || true

# This is my smoke-test.  I force the gracePeriod to be short
# and that we will move forward even if drain fails just because
# I am not testing kubectl drain or the pod disruption budgets here
# It also shows how you can override these values.  Normally, one
# would not want to "force" a drain unless you knew that all services
# on that node were expendable at the time.
# The commented out targetNode setting shows an example of that for
# my test cluster.  If it is not included, this runs as a status
# job.  If a target node is included, it runs as an actual image
# creation job.
${HELM3} upgrade --install smoke-test ../helm/vmss-prototype \
    --namespace default \
    --set kamino.name=kamino-smoketest \
    --set kamino.container.imageRegistry=${MY_ACR} \
    --set kamino.container.imageRepository=${MY_REPOSITORY} \
    --set kamino.container.imageTag=${MY_TAG} \
    --set kamino.container.pullByHash=false \
    --set kamino.container.pullSecret=skyman-acr \
    --set kamino.drain.gracePeriod=5 \
    --set kamino.drain.force=true \
    #--set kamino.targetNode=k8s-agentpool1-18861755-vmss000007

kubectl get jobs -lapp=kamino-vmss-prototype

# We background start the watch on the pod and then wait for
# the job to complete and then get the logs
kubectl get pods -o wide -lapp=kamino-vmss-prototype -w &
pod_watcher=$?
kubectl wait jobs --for condition=Complete -lapp=kamino-vmss-prototype
kubectl logs -lapp=kamino-vmss-prototype --tail 9999 --timestamps --follow
kill ${pod_watcher}
