# I would love to have distroless python but am not yet sure how best
# to get there, especially since we also need the Azure CLI too

# docker build . -t vmss-prototype:testing
# See smoketest.sh for examples of how I run locally

FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install --yes --no-install-suggests --no-install-recommends --yes \
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
        argcomplete \
        argparse \
        && \
    rm -rf /var/lib/apt/lists/* /root/.cache

# Azure CLI
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get -qq update && \
    apt-get -qq install --yes --no-install-suggests --no-install-recommends \
        azure-cli && \
    rm -rf /var/lib/apt/lists/* /root/.cache

COPY vmss-prototype /usr/bin/

ENTRYPOINT [ "/usr/bin/vmss-prototype" ]