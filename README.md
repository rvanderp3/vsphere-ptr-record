# vsphere-ptr-record

## Overview

Sets up a daemonset which serves PTR records for CI clients which require a PTR record. This daemonset
targets control plane nodes and exposes a NodePort which will be exposed on each control plane node. 
Clients should ideally add a nameserver for each control plane node.

## Configuring new subnets

1. Modify `gen-hosts.sh` to define the appropriate subnets to be added to the `hosts` file.
2. Commit changes.
3. Open a PR.
4. On approval, a new image will be built by quay.io.
5. Restart pods on the build cluster.

## Deploying daemonset

1. Create daemonset:
~~~sh
oc create -f manifests/daemonset.yaml
~~~
2. Create nodeport service:
~~~sh
oc create -f manifests/service.yaml
~~~