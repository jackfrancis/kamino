#!/bin/bash -e

# This uses the chart's defined container

# The helm binary - I use helm3 as the name as we had to support both in the past
HELM3=helm3

# The namespace we want to deploy to
NAMESPACE=default

DEPLOYMENT_NAME=smoke-test3

# Get rid of any prior version (just in case)
${HELM3} delete ${DEPLOYMENT_NAME} 2>/dev/null >/dev/null || true

# A simple smoketest.  We name it "kamino-${DEPLOYMENT_NAME}" such that it
# does not mix with the default jobs.  That name is use to help
# define/identify the job and pods.

# This has an override to the gracePeriod to be short and to force
# the operation even if drain fails as we are testing the deployment
# of the helm chart here.  Normally, one would not want to "force" a
# drain unless you knew that all services on that node were expendable
# We run this as an auto-deploy to all VMSS pools in the cluster.  It
# will only deploy to those pools that need it (updated OS patch/etc)
# Since this is for testing, we set the log level to DEBUG
# The annotations that are defined are from our test setup.
${HELM3} upgrade --install ${DEPLOYMENT_NAME} ../helm/vmss-prototype \
    --namespace ${NAMESPACE} \
    --set kamino.labels.app=${DEPLOYMENT_NAME} \
    --set kamino.logLevel=DEBUG \
    --set kamino.name=kamino-${DEPLOYMENT_NAME} \
    --set kamino.drain.gracePeriod=5 \
    --set kamino.drain.force=true \
    --set kamino.targetVMSS=ALL \
    --set kamino.auto.lastPatchAnnotation=LatestOSPatch \
    --set kamino.auto.pendingRebootAnnotation=PendingReboot \
    --set kamino.auto.maximumImageAge=15 \
    --set kamino.scheduleOnControlPlane=true \
    --set kamino.auto.dryRun=true

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