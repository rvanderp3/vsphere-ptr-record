FROM registry.access.redhat.com/ubi8/go-toolset:1.19.10-10.1692783630
USER root
RUN yum install -y bind-utils net-tools procps
RUN git clone git://thekelleys.org.uk/dnsmasq.git
WORKDIR dnsmasq
RUN make
RUN make install

COPY gen-hosts.sh gen-hosts.sh
RUN /bin/sh gen-hosts.sh
USER default
CMD dnsmasq -d -H hosts -a 0.0.0.0 -p 9053