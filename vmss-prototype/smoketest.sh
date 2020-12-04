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
   [[ ! -z ${CLUSTER_NAME} ]] &&
   [[ ! -z ${AZ_SUB} ]] &&
   [[ -f ${KUBECONFIG} ]] &&
   [[ -d ${HOME}/.azure ]]
   then
        docker run --rm -i -t \
            -v $(which kubectl):/usr/bin/kubectl:ro \
            -u ${UID}:${GID} \
            -v ${HOME}/.azure:${HOME}/.azure \
            -v ${KUBECONFIG}:${KUBECONFIG}:ro \
            -e USER=${USER} \
            -e HOME=${HOME} \
            -e KUBECONFIG=${KUBECONFIG} \
            ${IMAGE_TAG} \
            status \
                --name ${CLUSTER_NAME} \
                --resource-group SCM__${CLUSTER_NAME} \
                --subscription ${AZ_SUB}
fi
