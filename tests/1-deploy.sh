#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
TYPE="${1:?test type}"
TYPE="$(echo $TYPE | awk -F- '{print $1}')"

cd "$(dirname $0)"

if test -e ../.secrets
then source ../.secrets
else echo "missing .secrets - you should generate it"
     echo "to generate it, set .env variables from .env.dist then execute task secrets"
     echo "otherwise, just touch .secrets but be aware it will try to rebuild all the clusters (good luck)"
fi

# recode the id_rsa if setup
mkdir -p ~/.ssh
if test -n "$ID_RSA_B64"
then echo $ID_RSA_B64 | base64 -d >~/.ssh/id_rsa
     chmod 0600 ~/.ssh/id_rsa
fi

# disable preflight memory and cpu check
export PREFL_NO_CPU_CHECK=true
export PREFL_NO_MEM_CHECK=true

# actual setup
case "$TYPE" in
kind)
    # create vm with docker
    ops config reset
    ops setup devcluster --uninstall
    ops setup devcluster
    ;;
k3s)
    # create vm and install in the server
    ops config reset
    # create vm without k3s
    if test -n "$K3S_IP"
    then 
        echo $K3S_IP>_ip
        ops config apihost api.k3s.opsv.xyz
    else
        echo "Should fix when not K3S_IP"
        # TODO: fix this
        # task aws:vm:config
        # ops cloud aws vm-create k3s-test
        # ops cloud aws zone-update k3s.opsv.xyz --wildcard --vm=k3s-test
        # ops cloud aws vm-getip k3s-test >_ip
    fi
    # install openserverless
    ops config apihost auto --protocol=http
    ops setup server "$(cat _ip)" ubuntu --uninstall
    ops setup server "$(cat _ip)" ubuntu
    ;;
mk8s)
    ops config reset
    # create vm with mk8s
    if test -n "$MK8S_IP"
    then 
          ops config apihost api.mk8s.opsv.xyz
          ops cloud mk8s kubeconfig "$MK8S_IP" ubuntu
    else
        task aws:vm:config
        ops cloud aws vm-create mk8s-test
        ops cloud aws zone-update mk8s.opsv.xyz --wildcard --vm=mk8s-test
        ops cloud aws vm-getip mk8s-test >_ip
        ops cloud mk8s create "$(cat _ip)" ubuntu
        ops cloud mk8s kubeconfig "$(cat _ip)" ubuntu
    fi
    # install cluster
    ops setup cluster --uninstall
    ops setup cluster
    ;;
eks)
    ops config reset
    # create cluster
    if test -n "$EKS_KUBECONFIG_B64"
    then
        mkdir -p ~/.kube
        echo $EKS_KUBECONFIG_B64 | base64 -d >~/.kube/config
        ops config apihost api.eks.opsv.xyz
        ops config use 0
    else
        task aws:config
        task eks:config
        ops cloud eks create
        ops cloud eks kubeconfig
        ops cloud eks lb >_cname
        ops cloud aws zone-update eks.opsv.xyz --wildcard --cname=$(cat _cname)
        # on eks we need to setup an initial apihost resolving the NLB hostname
        ops config apihost api.eks.opsv.xyz
    fi
    # install cluster
    ops debug defin
    ops setup cluster --uninstall
    ops setup cluster
    ;;
aks)
    ops config reset
    # create cluster
    if test -n "$AKS_KUBECONFIG_B64"
    then
        mkdir -p ~/.kube
        echo $AKS_KUBECONFIG_B64 | base64 -d >~/.kube/config
        ops config use 0
        ops config apihost auto --protocol=http
        ops config apihost api.aks.opsv.xyz
    else
        task aks:config
        ops cloud aks create
        ops cloud aks kubeconfig
        task aws:config
        IP=$(ops cloud aks lb)
        ops cloud aws zone-update aks.opsv.xyz --wildcard --ip $IP
    fi
    # install cluster
    ops debug defin
    ops setup cluster --uninstall
    ops setup cluster
    ;;
gke)
    ops config reset
    # create cluster
    if test -n "$GCLOUD_SERVICE_ACCOUNT_B64"
    then     
        mkdir -p ~/.kube
        echo "$GCLOUD_SERVICE_ACCOUNT_B64" | base64 -d  >~/.kube/gcloud.json
        gcloud auth activate-service-account --key-file ~/.kube/gcloud.json
        gcloud container clusters get-credentials nuvolaris-testing --project nuvolaris-testing --region=us-east1
        
        ops config use 0
        ops config apihost api.gke.opsv.xyz
    else
        task gcp:vm:config
        task aws:vm:config
        ops cloud gke create
        ops cloud gke kubeconfig
        ops cloud aws zone-update gke.opsv.xyz --wildcard --ip $(ops cloud gke lb)
    fi
    # install cluster
    ops debug defin
    ops setup cluster --uninstall
    ops setup cluster
    ;;

osh)
    ops config reset
    # create cluster
    if test -n "$OPENSHIFT_KUBECONFIG_B64"
    then
        mkdir -p ~/.kube
        echo $OPENSHIFT_KUBECONFIG_B64 | base64 -d >~/.kube/config
        ops config use 0
        ops config apihost api.apps.nuvolaris-testing.oshgcp.opsv.xyz
    else
        task osh:create
        ops cloud osh import conf/gcp/auth/kubeconfig
    fi
    # install cluster
    ops debug defin
    ops setup cluster --uninstall
    ops setup cluster
    ;;

esac
