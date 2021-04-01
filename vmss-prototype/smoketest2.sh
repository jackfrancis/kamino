#!/bin/bash -e

MY_ACR=skyman.azurecr.io
MY_REPOSITORY=scratch/kamino/vmss-prototype
MY_TAG=experimental.msinz

# The namespace we want to deploy to
NAMESPACE=default
DEPLOYMENT_NAME=smoke-test2

az acr login -n ${MY_ACR}

IMAGE_TAG=${MY_ACR}/${MY_REPOSITORY}:${MY_TAG}

docker build . -t ${IMAGE_TAG}

docker run --rm -i -t ${IMAGE_TAG} --help

docker push ${IMAGE_TAG}
docker history ${IMAGE_TAG}

# The helm binary - I use helm3 as the name as we had to support both in the past
HELM3=helm3

# Get rid of any prior version (just in case)
${HELM3} delete ${DEPLOYMENT_NAME} 2>/dev/null >/dev/null || true

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
${HELM3} upgrade --install ${DEPLOYMENT_NAME} ../helm/vmss-prototype \
    --namespace ${NAMESPACE} \
    --set kamino.labels.app=${DEPLOYMENT_NAME} \
    --set kamino.logLevel=DEBUG \
    --set kamino.name=kamino-${DEPLOYMENT_NAME} \
    --set kamino.container.imageRegistry=${MY_ACR} \
    --set kamino.container.imageRepository=${MY_REPOSITORY} \
    --set kamino.container.imageTag=${MY_TAG} \
    --set kamino.container.pullByHash=false \
    --set kamino.container.pullSecret=skyman-acr \
    --set kamino.drain.gracePeriod=5 \
    --set kamino.drain.force=true \
    #--set kamino.targetNode=k8s-agentpool1-18861755-vmss000007

# Show the commands we are about to run
set -x

# Show the job...
kubectl get jobs --namespace ${NAMESPACE} --selector app=${DEPLOYMENT_NAME}

# Wait for the job to be ready
kubectl wait --timeout 90s --for condition=Ready pods --namespace ${NAMESPACE} --selector app=${DEPLOYMENT_NAME}

# Note that I do this here knowing that it will never exit and that
# I am just watching it start/etc.  That was the whole point.
kubectl get pods --namespace ${NAMESPACE} --selector app=${DEPLOYMENT_NAME} --output wide

# Now show the logs (with --follow which will run until the job completes)
kubectl logs --timestamps --namespace ${NAMESPACE} --selector app=${DEPLOYMENT_NAME} --follow --tail 1000
