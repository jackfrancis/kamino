#!/bin/bash -e

IMAGE_TAG=vmss-prototype:smoke-test

docker build . -t ${IMAGE_TAG}

docker run --rm -i -t ${IMAGE_TAG} --help

# A form to test locally with my local azure login and kubectl from
# my host machine by mapping in the .azure directory and the KUBECONFIG file
# and passing on the cluster name (in our case my cluster name is part of
# the resource group name so I can test like this.  Others may not)
# When run in the cluster, other mechanisms would be used
if [[ ! -z ${KUBECONFIG} ]] &&
   [[ ! -z ${RESOURCE_GROUP} ]] &&
   [[ ! -z ${AZ_SUB} ]] &&
   [[ -f ${KUBECONFIG} ]] &&
   [[ -d ${HOME}/.azure ]]
   then
        docker run --rm -i -t \
            -u ${UID}:${GID} \
            --mount type=bind,source=$(which kubectl),target=/usr/bin/kubectl,readonly \
            --mount type=bind,source=${HOME}/.azure,target=${HOME}/.azure \
            --mount type=bind,source=${KUBECONFIG},target=${KUBECONFIG},readonly \
            -e USER=${USER} \
            -e HOME=${HOME} \
            -e KUBECONFIG=${KUBECONFIG} \
            ${IMAGE_TAG} \
            status \
                --resource-group ${RESOURCE_GROUP} \
                --subscription ${AZ_SUB}
fi
