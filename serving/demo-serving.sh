#!/usr/bin/env bash

. ../base-scripts/demo-magic.sh

########################
# Configure the options
########################

TYPE_SPEED=40
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "
DEMO_CMD_COLOR=$WHITE

# demo props
NAMESPACE=knative-serving-demo

# hide the evidence
clear

if [ -z "$1" ]
then
 echo "Use ..."
 echo " $0 run"  
 echo " $0 prep" 
 echo " $0 delete"  
 exit
fi

if [ "$1" == "prep" ]
then

  printf "Check if oc and kn CLI is installed and if knative is installed in the cluster \n"
  pei "oc whoami && oc config current-context || oc login"
  pei "kn version"
  pei "oc version"
  pei "oc get projects | grep knative"
  exit

fi

if [ "$1" == "run" ]
then
  ######## Validate Knative Serving Installation
  pe "oc get knativeserving knative-serving -n knative-serving -o yaml |grep -A 15 conditions"
  pe "oc get pods -n knative-serving"
  pe "oc get pods -n knative-serving-ingress"
  ######## Create the namespace
  pe "oc new-project $NAMESPACE"
  ######## Create the Service (Quarkus native REST API)
  pe "kn service create quarkus-rest-api --image quay.io/oschneid/quarkus-rest --port=8080"
  pe "kn service list"
  pe "kn revision list"
  pe "kn routes list"
  ######## Show Service details and dependents
  pe "oc tree ksvc quarkus-rest-api"
  ######## Create a service in offline mode
  pe "kn service create quarkus-rest-api-offline --image quay.io/oschneid/quarkus-rest --target ./ --namespace $NAMESPACE"
  pe "tree ./"
  pe "vi ./$NAMESPACE/ksvc/quarkus-rest-api-offline.yaml"
  pe "oc apply -f ./$NAMESPACE/ksvc/"
  ######## Cluster local services
  pe "kn service update quarkus-rest-api-offline --cluster-local"
  pe "oc get routes -n knative-serving-ingress"
  pe "kn service delete quarkus-rest-api-offline"
  ######## Access the endpoint
  pe "ROUTE=\$(oc get ksvc | grep quarkus-rest-api | awk 'NR==1 {print \$2 }')"
  #pe "open \$ROUTE/swagger-ui"
  pe "curl -I -X 'POST' \$ROUTE/gateways/announces -H 'accept: */*' -H 'Content-Type: application/json'"
  ######## Configure Autoscaling
  pe "oc get configmap config-autoscaler -n knative-serving -o yaml"
  pe "kn service update quarkus-rest-api --concurrency-limit 1 --scale-window=10s"
  #pe "kn service update quarkus-rest-api --scale-target 5 --scale-window=10s"
  pe "kn revision list"
  pe "fortio load -t 20s -c 10 -qps 40 -timeout 10000ms \$ROUTE/gateways/announces"
  pe "kn service update quarkus-rest-api --scale-max 10 --annotation autoscaling.knative.dev/metric=rps --scale-target 1 --scale-window=10s"
  #pe "oc edit ksvc quarkus-rest-api"
  pe "fortio load -t 20s -c 1 -qps 8 -timeout 10000ms \$ROUTE/gateways/announces"
  ######## Traffic Management
  pe "kn revision list"
  pe "kn service update quarkus-rest-api --traffic quarkus-rest-api-00003=100"
  pe "kn service update quarkus-rest-api --env version=GREEN --revision-name=green-revision"
  pe "kn revision list"
  pe "fortio load -t 10s -c 1 -qps 5 -timeout 10000ms \$ROUTE/gateways/announces"
  pe "kn service update quarkus-rest-api --tag @latest=green"
  pe "kn revision list"
  pe "oc get routes -n knative-serving-ingress"
  #pe "fortio load -t 10s -c 1 -qps 5 -timeout 10000ms \$ROUTE/gateways/announces"
  pe "kn service update quarkus-rest-api --traffic green=20,quarkus-rest-api-00003=80"
  pe "kn revision list"
  pe "fortio load -t 10s -c 1 -qps 5 -timeout 10000ms \$ROUTE/gateways/announces"
  exit
fi

if [ "$1" == "delete" ]
then
  pe "oc delete project $NAMESPACE"
  exit
fi
