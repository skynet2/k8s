#!/usr/bin/env bash
#
# Copyright SecureKey Technologies Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
set -e

PATCH=.ingress_coredns.patch
COREDNS_CM=.coredns.bak.json
# List of services used to generate domain names
mapfile -t SERVICES < service_list.txt

SERVICES2=()

for srv in ${SERVICES[@]}; do
  srv=$(echo "$srv"|tr -d '\r\n'|tr -d '\n')
  if [[ $srv ]]; then
    SERVICES2+=($srv)
  fi;
done
SERVICES=( "${SERVICES2[@]}" )

MINIKUBE_IP=$( minikube ip )
: ${DOMAIN:=trustbloc.dev}

generate_host_entries() {
    for service in ${SERVICES[@]}; do
        echo "$1$MINIKUBE_IP $service.$DOMAIN"
    done
}

# Patch coredns configMap
echo 'Patching coredns configMap (adding custom service entries to the hosts section)...'
kubectl get cm coredns -n kube-system -o json > $COREDNS_CM

if ! grep -q hosts $COREDNS_CM; then
    echo 'hosts section does not exist, adding it'

    # Generate coredns configMap patch
    echo '        hosts {' > $PATCH
    generate_host_entries '          ' >> $PATCH
    echo '          fallthrough' >> $PATCH
    echo '        }' >> $PATCH

    EDITOR='sed -i "/loadbalance/r.ingress_coredns.patch"' kubectl edit cm coredns -n kube-system
else
    echo 'hosts section already exists, patching it'

    # Generate new Corefile for replacement
    jq -r '.data.Corefile' $COREDNS_CM > .Corefile.config
    HOSTS_START_LINE=$( grep -n 'hosts {' .Corefile.config | cut -d : -f 1 )
    head -$HOSTS_START_LINE .Corefile.config > $PATCH
    generate_host_entries '       ' >> $PATCH
    tail +$(( HOSTS_START_LINE + 1 )) .Corefile.config >> $PATCH

    echo '=== listing the patched Corefile ==='
    cat $PATCH
    echo '=== end patched Corefile listing ==='

    jq --arg replace "`cat $PATCH`" '.data.Corefile = $replace' $COREDNS_CM | kubectl apply -f -
fi

echo 'Running kubectl rollout restart for coredns...'
kubectl rollout restart deployment/coredns -n kube-system

echo 'Verifying that DNS resolution works inside the cluster'

ROLLOUT_CHECK=
if kubectl rollout status deployment/coredns -n kube-system --timeout=60s; then
    ROLLOUT_CHECK='success'
fi

DNS_CHECK=
if [[ $ROLLOUT_CHECK = 'success' ]]; then
    DNS_CHECK_SCRIPT="for svc in ${SERVICES[*]}; do echo Checking DNS for \$svc...; host \$svc.$DOMAIN; done"
    if kubectl run dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 --rm --attach --command --restart=Never -- sh -ec "$DNS_CHECK_SCRIPT"; then
        DNS_CHECK='success'
    fi
fi

if [[ $ROLLOUT_CHECK = 'success' && $DNS_CHECK = 'success' ]]; then
    echo 'Done patching coreDNS configMap'
else
    echo 'DNS resolution test failed, rolling back the coreDNS configMap'
    kubectl apply -f $COREDNS_CM -n kube-system --force=true
    kubectl rollout undo deployment/coredns -n kube-system
    exit 11
fi
