# I would love to have distroless python but am not yet sure how best
# to get there, especially since we also need the Azure CLI too

# docker build . -t vmss-prototype:testing
# See smoketest.sh for examples of how I run locally

# Comes in at ~73MB
FROM ubuntu:20.04

# Currently adds ~66MB due to patches/updates and our requirements
RUN apt-get update && \
    apt-get upgrade --yes && \
    apt-get install --no-install-suggests --no-install-recommends --yes \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        python3 \
        python3-pip \
        && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 4 && \
    python -m pip install --upgrade pip && \
    python -m pip install \
        argparse \
        && \
    rm -rf /var/lib/apt/lists/* /root/.cache

# Azure CLI (Currently ~789MB all by itself!)
RUN echo "Install AzureCLI" && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=true apt-key add - && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get -qq update && \
    apt-get -qq install --yes --no-install-suggests --no-install-recommends azure-cli && \
    rm -rf /var/lib/apt/lists/* /root/.cache

# A tiny ~75KB
COPY vmss-prototype /usr/bin/

ENTRYPOINT [ "/usr/bin/vmss-prototype" ]
