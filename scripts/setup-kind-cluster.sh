#!/bin/bash
set -e

# This script sets up a kind cluster with cert-manager
# Can be used standalone or called by other scripts
#
# Usage:
#   ./setup-kind-cluster.sh [cluster-name]
#
# Environment variables:
#   KIND_CLUSTER_NAME - Name of the kind cluster (default: aso2)

KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-${1:-aso2}}

if ! (kind get clusters 2>/dev/null|grep -q '^'"$KIND_CLUSTER_NAME"'$') ; then
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    KIND_CFG_NAME="$SCRIPT_DIR/kind-config-$KIND_CLUSTER_NAME.yaml"
    KIND_OPTS="" 
    if [ -f "$KIND_CFG_NAME" ] ; then
        KIND_OPTS="$KIND_OPTS --config=$KIND_CFG_NAME"
    fi
    kind create cluster --name "$KIND_CLUSTER_NAME" --image="kindest/node:v1.31.0" $KIND_OPTS
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true --wait --timeout 5m
fi
