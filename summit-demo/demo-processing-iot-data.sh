#!/usr/bin/env bash

. ./demo-magic.sh

########################
# Configure the options
########################

TYPE_SPEED=40
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "
DEMO_CMD_COLOR=$WHITE

# demo props
NAMESPACE=bobbycar-drogue

# hide the evidence
clear

if [ -z "$1" ]
then
 echo "Use ..."
 echo " $0 demo"  
 echo " $0 sendCE"
 echo " $0 func"  
 exit
fi

if [ "$1" == "sendCE" ]
then
    pe "curl -v -X 'POST' http://external-broker-knative-eventing.apps.ocp4.rhlab.de/bobbycar-telemetry-external/telemetry-ai \\
        -H 'Ce-Id: say-hello' \\
        -H 'Ce-Specversion: 1.0' \\
        -H 'Ce-Type: my-type' \\
        -H 'Ce-Source: mycurl' \\
        -H 'Content-Type: application/json' \\
        -d '{msg:Hello Knative}'"
fi

if [ "$1" == "func" ]
then
  ## switch to project
  pe "oc project bobbycar-drogue"
  pe "kn func languages"
  pe "kn func create my-func -l quarkus -t cloudevents"
  pe "tree ./my-func"
  pe "cd demo/event-recorder"
  #pe "kn func build -v"
  #pe "kn func run -v"
  #pe "kn func invoke"
  #pe "kn func invoke -f=cloudevent -t='http://localhost:8080' --data='Hello Ortwin'"
  pe "kn func deploy -v"
  #pe "oc apply -f ../../k8s/pvc.yaml"
  #printf "\nNow we configure the volume for the Knative Service \n\n"
  pe "kn func invoke -f=cloudevent --target=remote --data='Hello OpenShift Serverless'"
fi

if [ "$1" == "demo" ]
then

  ## switch to project
  pe "oc project bobbycar-drogue"
  ## Create the telemetry broker
  pe "kn broker create telemetry"
  ## Create the Consumer
  pe "kn service create device-logger --image gcr.io/knative-releases/knative.dev/eventing-contrib/cmd/event_display --scale-window=60s"
  pe "kn service list"
  pe "kn revision list"
  ## create trigger for event-consumer
  pe "kn trigger create telemetry-trigger --broker telemetry --sink ksvc:device-logger"
  ## Update event-consumer, modify scaling
  pe "kn service update device-logger --scale-max 5 --annotation autoscaling.knative.dev/metric=rps --scale-target 1 --scale-window=30s"
  ## Show new revision
  pe "kn revision list"
  ## split traffic
  pe "kn service update device-logger --traffic device-logger-00001=70,device-logger-00002=30"
  ## create trigger for internal broker mesh
  pe "kn trigger create telemetry-audit-gps-trigger --broker telemetry --sink broker:bobbycar --filter subject=car"
  ## create trigger for external events
  pe "kn trigger create telemetry-ml-metrics-ext-trigger --filter subject=carMetrics --broker telemetry --sink http://external-broker-knative-eventing.apps.ocp4.rhlab.de/bobbycar-telemetry-external/telemetry-ai"
  pe "kn trigger list"
  exit

fi

