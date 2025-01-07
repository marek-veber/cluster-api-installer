#!/bin/bash
set -e

if [ -z "$ORGREPO" ]; then
    echo "ORGREPO must be provided ex; https://github.com/openshift"
    exit -1
fi
if [ -z "$PROJECT" ] ; then
    echo "PROJECT name must be provided ex; cluster-api, cluster-api-providers-aws, cluster-api-providers-azure"
    exit -1
fi
if [ -z "$BRANCH" ]; then
    echo "BRANCH must be provided ex; master, release-4.18"
    exit -1
fi
if [ -z "$KUSTOMIZE" ] ; then
    echo "kustomize command ref must be set"
    exit -1
fi

WKDIR=../out
CONFIGDIR=config
TMPDIR=tmp

if [ "$SKIP_CLONE" != true -o ! -d $WKDIR/$PROJECT ] ; then
    mkdir -p $WKDIR
    rm -rf $WKDIR/$PROJECT
    mkdir $WKDIR/$PROJECT
    git clone $ORGREPO/$PROJECT $WKDIR/$PROJECT
fi

export KUSTOMIZE_PLUGIN_HOME=$(realpath ../kustomize-plugins)
[ -f ../$CONFIGDIR/$PROJECT/env ] && . ../$CONFIGDIR/$PROJECT/env
cp ../$CONFIGDIR/$PROJECT/kustomization.yaml $WKDIR/$PROJECT/$CONFIGDIR
[ -d ../$CONFIGDIR/$PROJECT/base ] && cp -a ../$CONFIGDIR/$PROJECT/base $WKDIR/$PROJECT/$CONFIGDIR

cd $WKDIR/$PROJECT
git checkout "$BRANCH" && git pull
rm -rf $CONFIGDIR/$TMPDIR
mkdir -p $CONFIGDIR/$TMPDIR
$KUSTOMIZE build --enable-alpha-plugins config -o $CONFIGDIR/$TMPDIR
rm -rf $CONFIGDIR/$TMPDIR/cert*
rm -rf $CONFIGDIR/$TMPDIR/apiextensions.k8s.io_v1_customresourcedefinition_ip*.yaml

echo $WKDIR/$PROJECT/$CONFIGDIR/$TMPDIR
