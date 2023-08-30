FROM registry.access.redhat.com/ubi8/go-toolset:1.19.10-10.1692783630
USER root
RUN yum install -y bind-utils net-tools procps jq
RUN wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.13.10/openshift-client-linux.tar.gz
RUN tar xf openshift-client-linux.tar.gz -C /usr/local/bin
RUN git clone git://thekelleys.org.uk/dnsmasq.git
WORKDIR dnsmasq
RUN make
RUN make install
COPY dnsmasq.conf dnsmasq.conf
COPY gen-hosts.sh gen-hosts.sh
COPY secret-check.sh secret-check.sh
USER default
CMD /bin/sh ./gen-hosts.sh