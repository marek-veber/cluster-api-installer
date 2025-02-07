#!/usr/bin/bash
set -e
if [ "${DO_DEPLOY:=true}" == "true" ] ; then
    [ "$CUSTOMIZE_CAPIS" == "true" ] && {
        for i in 1 2 ; do
            CH_DIR="charts/cluster-api$i"
            rm -rf "$CH_DIR"/{crds,templates}
            mkdir -p "$CH_DIR"/{crds,templates}
            ./hack/tools/kustomize build config/cluster-api${i} --load-restrictor LoadRestrictionsNone -o "$CH_DIR/templates"
            if ls "$CH_DIR/templates" | grep -q ^apiextensions ; then
                mv "$CH_DIR/templates"/apiextensions*.yaml "$CH_DIR/crds"
            fi
            sed -e 's/\(capi-webhook-service.capi\)\(-system\.\)/\1'"$i"'\2/' -i charts/cluster-api${i}/templates/cert-manager.io_v1_certificate_capi-serving-cert.yaml
        done
        sed -e 's/,MachineWaitForVolumeDetachConsiderVolumeAttachments=true,PriorityQueue=false//'  -i charts/cluster-api2/templates/apps_v1_deployment_capi-controller-manager.yaml
    } 
    [ "$KIND_DELETE" == "true" ] && {
       kind delete cluster --name=kind
       kind create cluster --name kind
       helm repo add jetstack https://charts.jetstack.io
       helm repo update
       helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true \
          --wait --wait-for-jobs --timeout 3h
    }
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
