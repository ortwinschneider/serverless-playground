#!/usr/bin/env bash

. ../base-scripts/demo-magic.sh

########################
# Configure the options
########################

TYPE_SPEED=30
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "
DEMO_CMD_COLOR=$WHITE

# demo props
NAMESPACE=knative-camelk-demo

# hide the evidence
clear

if [ -z "$1" ]
then
 echo "Use ..."
 echo " $0 run"  
 echo " $0 check" 
 echo " $0 cleanup"  
 exit
fi

if [ "$1" == "check" ]
then

  printf "Check if oc and kn CLI is installed and if knative is installed in the cluster \n"
  pei "oc whoami && oc config current-context || oc login"
  pei "kn version"
  pei "oc version"
  pei "kamel version"
  pei "oc get projects | grep knative"
  exit

fi

if [ "$1" == "run" ]
then
  ######################
  # Create the namespace
  ######################
  pe "oc new-project $NAMESPACE"

  pe "kn source list-types"

  ######################
  # Install Camel-K operator 
  ######################
  pe "oc apply -f ./operator/camel-k-og.yaml"
  pe "oc apply -f ./operator/camel-k-csv.yaml"

  pe "kamel kamelet get"
  pe "oc apply -f https://raw.githubusercontent.com/apache/camel-kamelets/v0.6.0/kamelets/github-source.kamelet.yaml"
  pe "kamel kamelet get --source"
  pe "oc edit kamelet aws-s3-source"

  ######################
  # Create a new Camel-K Service
  ######################
  pe "kamel init HelloServerless.java"
  pe "kamel run --dev --name hello-world HelloServerless.java"
  # Now add -> .to("knative:event/my.camel.event.type?kind=Broker&name=mybroker");

  ######################
  # Create a Knative Broker, event-display and a trigger 
  ###################### 
  pe "kn broker create mybroker"
  pe "kn service create event-display --image gcr.io/knative-releases/knative.dev/eventing-contrib/cmd/event_display"
  pe "kn trigger create mytrigger --broker mybroker --sink ksvc:event-display"
  pe "kamel run --dev HelloServerless.java --trait knative.enabled=true --profile knative"

  ######################
  # Create a second Camel-K Integration as Knative Service
  ###################### 
  pe "kamel init CKService.java"
  # from("knative:endpoint/myendpoint")
  pe "kamel run --name ck-service CKService.java --profile knative --trait knative-service.enabled=true"
  pe "kn trigger create cktrigger --broker mybroker --sink ksvc:ck-service"

  ######################
  # Create a Kamelet Binding
  ######################
  pe "oc apply -f aws-s3-secret.yaml"
  pe "vi aws-flow-binding.yaml"
  pe "oc apply -f aws-flow-binding.yaml"
  printf "\n CLI example: kn source kamelet binding create --kamelet=aws-s3-source --broker=mybroker --property=bucketNameOrArn=mybucket ... \n"
  pe "watch oc get pods"
  pe "aws s3 cp test.txt s3://oschneid-knative"
  exit
fi

if [ "$1" == "cleanup" ]
then
  pe "oc delete project $NAMESPACE"
  exit
fi
