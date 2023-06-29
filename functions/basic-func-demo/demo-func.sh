#!/usr/bin/env bash

. ../../base-scripts/demo-magic.sh

########################
# Configure the demo envs
########################

NAMESPACE=knative-functions-demo
APP_DOMAIN=apps.ocp4.rhlab.de
GIT_REPO_URL=https://github.com/ortwinschneider/handle-gps.git


########################
# Configure the options
########################

TYPE_SPEED=40
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "
DEMO_CMD_COLOR=$WHITE

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
  pei "kn func version"
  pei "oc version"
  pei "oc get projects | grep knative"
  exit
fi

if [ "$1" == "run" ]
then
  # Create the namespace
  pe "oc new-project $NAMESPACE"
  # Create a function project
  pe "kn func create handle-gps -l node -t cloudevents"
  pe "cd handle-gps/ && tree ."
  # Configure ENVS (interactiv)
  pe "kn func config"
  # Build and test locally
  pe "kn func build -v"
  pe "kn func run"
  # Deploy to cluster
  pe "oc create configmap fnconfig --from-literal=MESSAGE='Hi from Cluster'"
  # Delete ENV (interactiv)
  pe "kn func config"
  # Add ENV from configmap (interactiv)
  pe "kn func config"
  # Deploy to cluster
  pe "kn func deploy -v"
  pe "kn services list"
  pe "kn func list"
  pe "kn func info"
  pe "kn func invoke --target https://handle-gps-$NAMESPACE.$APP_DOMAIN"
  
  ## Modify the implementation -> copy from snippets

  # Install Tekton Tasks for Cluster Build
  #pe "oc apply -f https://raw.githubusercontent.com/knative-sandbox/kn-plugin-func/main/pipelines/resources/tekton/task/func-s2i/0.1/func-s2i.yaml"
  pe "oc apply -f https://raw.githubusercontent.com/knative-sandbox/kn-plugin-func/main/pipelines/resources/tekton/task/func-buildpacks/0.1/func-buildpacks.yaml"
  pe "oc apply -f https://raw.githubusercontent.com/knative-sandbox/kn-plugin-func/main/pipelines/resources/tekton/task/func-deploy/0.1/func-deploy.yaml"

  # create Git repo and push project
  pe "git init && git add ."
  pe "git commit -m 'initial commit'"
  pe "git branch -M main"
  pe "git remote add origin $GIT_REPO_URL"
  pe "git push -u origin main"
  # Edit the func.yaml to use git build
  echo 'Now Edit the func.yaml'
  # Trigger the Tekton pipeline
  pe "kn func deploy -v"

  # Create Kafka native broker implementation
  pe "oc get configmap/kafka-broker-config -n knative-eventing -o yaml"
  pe "vi ../../../eventing/kafka-broker.yaml"
  pe "oc apply -f ../../../eventing/kafka-broker.yaml"
  # List the Kafka topics
  pe "oc exec bobbycar-cluster-kafka-0 -n bobbycar -- bin/kafka-topics.sh --bootstrap-server=localhost:9092 --list"

  # Manually create a Kafka source and connect to broker and the function

  exit
fi

if [ "$1" == "delete" ]
then
  pe "oc delete project $NAMESPACE"
  exit
fi
