#!/usr/bin/bash
set -e
if [ "${DO_DEPLOY:=true}" == "true" ] ; then
    if [ "$UPDATE_RESOURCES" == "true" ] ; then
        for i in 1 2 ; do
            CH_DIR="charts/cluster-api$i"
            rm -rf "$CH_DIR"/{crds,templates}
            mkdir -p "$CH_DIR"/{crds,templates}
            kustomize build config/cluster-api${i} --load-restrictor LoadRestrictionsNone -o "$CH_DIR/templates"
            if ls "$CH_DIR/templates" | grep -q ^apiextensions ; then
                mv "$CH_DIR/templates"/apiextensions*.yaml "$CH_DIR/crds"
            fi
        done
    fi
    
    [ "$CRC_DELETE" == "true" ] && crc delete --force
    crc start -p ~/crc/pull-secret.txt > /dev/null
    export KUBECONFIG=$HOME/.crc/machines/crc/kubeconfig
    echo KUBECONFIG=$KUBECONFIG
    for CHART in charts/cluster-api1 charts/cluster-api2 charts/cluster-api-provider-aws ; do
        [ -f $CHART/Chart.yaml ] || continue
        echo ========= deploy: $CHART $HELM_ARGS
        helm template $CHART --include-crds|kubectl apply -f -
        echo
    done
    echo;echo
fi

for T in capi1 capi2 capa; do
    echo "Waiting for ${T} controller:"
    kubectl events -n ${T}-system --watch &
    CH_PID=$!
    kubectl -n ${T}-system wait deployment/${T%%[0-9]}-controller-manager --for condition=Available=True  --timeout=10m
    kill $CH_PID
    echo
done
