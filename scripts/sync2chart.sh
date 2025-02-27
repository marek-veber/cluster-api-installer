#!/bin/bash
set -e

if [ -z "$PROJECT" ] ; then
    echo "PROJECT name must be defned ex; cluster-api, cluster-api-providers-aws, cluster-api-providers-azure"
    exit -1
fi
if [ -z "$PROVIDER_VERSION" ]; then
    echo "PROVIDER_VERSION must be defned ex; 4.18"
    exit -1
fi
if [ -z "$OCP_VERSION" ]; then
    echo "OCP_VERSION must be defned ex; 4.18"
    exit -1
fi
if [ -z "$BUILTDIR" ]; then
    echo "BUILTDIR must be set"
    exit -1
fi


CHARTDIR=../charts/$PROJECT
NEWCHART=$BUILTDIR/new-chart.yml

if [ "$SYNC2CHARTS" ] ;then
    echo 'sync new output to ' $CHARTDIR
    rm -rf $CHARTDIR/templates/*.yaml
    rm -rf $CHARTDIR/crds/*.yaml
    mv $BUILTDIR/apiextensions*.yaml $CHARTDIR/crds
    mv $BUILTDIR/*.yaml $CHARTDIR/templates

    echo "updating versions($OCP_VERSION) in:" "$CHARTDIR/Chart.yaml" "$CHARTDIR/values.yaml"
    sed -i -e 's/^\(version\|appVersion\): .*/\1: "'"$OCP_VERSION"'"/' "$CHARTDIR/Chart.yaml"
    TAG_VERSION="$PROVIDER_VERSION"
    if "$TAG_VERSION" : "[0-9]" ; then TAG_VERSION="v$TAG_VERSION" ; fi
    sed -i -e 's/^\(    tag: \).*/\1'"$TAG_VERSION"/ "$CHARTDIR/values.yaml"
    
    echo 'Run helm template after sync saving the output to ' $NEWCHART
    $HELM template $CHARTDIR --include-crds | \
      grep -v '^#' > $NEWCHART
    
    if [ "$SORTED_OUTPUT" == "true" ] ; then
      $YQ ea '[.] | sort_by(.apiVersion,.kind,.metadata.name) | .[] | splitDoc|sort_keys(..)' < "$NEWCHART" > "${NEWCHART#.yaml}-sorted.yaml"
    fi
fi
