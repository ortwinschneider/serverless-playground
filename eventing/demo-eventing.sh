#!/usr/bin/env bash

. ../base-scripts/demo-magic.sh

########################
# Configure the options
########################

TYPE_SPEED=40
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "
DEMO_CMD_COLOR=$WHITE

# demo props
NAMESPACE=knative-eventing-demo

clear

if [ -z "$1" ]
then
 echo "Use ..."
 echo " $0 run"  
 echo " $0 check" 
 echo " $0 delete"  
 exit
fi

if [ "$1" == "check" ]
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

  ######################
  # Verify the installation
  ###################### 
  pe "oc get knativeeventing knative-eventing -n knative-eventing -o yaml |grep -A 15 conditions"
  pe "oc get pods -n knative-eventing"
  pe "kn source list-types"

  ######################
  # Create the namespace
  ######################
  pe "oc new-project $NAMESPACE"

  ######################
  # Source to Sink 
  ###################### 
  pe "kn service create event-consumer --image gcr.io/knative-releases/knative.dev/eventing-contrib/cmd/event_display --scale-window=10s"
  pe "kn service list"
  pe "ROUTE_EC=\$(oc get ksvc | grep event-consumer | awk 'NR==1 {print \$2 }')"
  pe "curl -v -X 'POST' \$ROUTE_EC \\
  -H 'Ce-Id: say-hello' \\
  -H 'Ce-Specversion: 1.0' \\
  -H 'Ce-Type: my-type' \\
  -H 'Ce-Source: mycurl' \\
  -H 'Content-Type: application/json' \\
  -d '{msg:Hello Knative}'"
  pe "kn source ping create ping-event-producer --schedule '* * * * *' --data '{ value: 'Ping' }' --sink ksvc:event-consumer"

  ######################
  # Channel and Subscriptions
  ###################### 
  pe "kn channel create my-channel"
  pe "kn source ping update ping-event-producer --sink channel:my-channel"
  pe "kn subscription create event-consumer-sub --channel my-channel --sink ksvc:event-consumer"
  pe "kn service create event-display --image gcr.io/knative-releases/knative.dev/eventing-contrib/cmd/event_display --scale-window=10s"
  pe "kn subscription create event-display-sub --channel my-channel --sink event-display"

  pe "kn subscription delete event-display-sub"
  pei "kn subscription delete event-consumer-sub"
  pei "kn channel delete my-channel"
  #pei "kn source ping delete ping-event-producer"
  pei "kn service delete event-display"

  ######################
  # Kafka Channel
  ######################
  #pe "oc get pods -n bobbycar | grep kafka"
  pe "oc get knativekafka knative-kafka -n knative-eventing -o yaml"
  pe "kn channel list-types"
  pe "kn channel create my-kafka-channel --type messaging.knative.dev:v1beta1:KafkaChannel"
  pe "oc exec bobbycar-cluster-kafka-0 -n bobbycar -- bin/kafka-topics.sh --bootstrap-server=localhost:9092 --list"

  pe "vi amq-topic.yaml"
  pe "oc apply -f amq-topic.yaml -n bobbycar"
  pe "oc exec bobbycar-cluster-kafka-0 -n bobbycar -- bin/kafka-topics.sh --bootstrap-server=localhost:9092 --list"
  pe "vi kafka-source.yaml"
  pe "oc apply -f kafka-source.yaml"
  pe "kn subscription create channel-consumer-sub --channel my-kafka-channel --sink ksvc:event-consumer"
  pe "oc exec -i -t bobbycar-cluster-kafka-0 -n bobbycar -- bin/kafka-console-producer.sh --bootstrap-server=localhost:9092 --topic serverless-orders"

  ######################
  # Broker and Triggers
  ###################### 
  pe "kn broker create mybroker"
  pe "kn service create ping-consumer --image gcr.io/knative-releases/knative.dev/eventing-contrib/cmd/event_display --scale-window=10s"
  pe "kn trigger create mytrigger --broker mybroker --filter type=dev.knative.sources.ping --sink ksvc:ping-consumer"
  pe "kn trigger list"
  pe "oc get trigger mytrigger"
  pe "kn source ping update ping-event-producer --sink broker:mybroker"
  
  ######################
  # External access to the Broker 
  ###################### 
  #pe "oc get routes,svc -n knative-eventing"
  pe "vi broker-route.yaml"
  pe "oc apply -f broker-route.yaml -n knative-eventing"
  pe "oc get routes -n knative-eventing"
  pe "kn broker describe mybroker"
  #pe "ROUTE_BROKER=\$(oc get broker | grep mybroker | awk 'NR==1 {print \$2 }')"
  pe "curl -v -X 'POST' http://broker-knative-eventing.apps.ocp4.rhlab.de/$NAMESPACE/mybroker \\
  -H 'Ce-Id: kn-order-123' \\
  -H 'Ce-Specversion: 1.0' \\
  -H 'Ce-Type: kn-order' \\
  -H 'Ce-Source: local-curl' \\
  -H 'Content-Type: application/json' \\
  -d '{orderId:123, custName: Schneider, orderItems: []}'"
  
  exit
fi

if [ "$1" == "delete" ]
then
  pe "oc delete project $NAMESPACE"
  pei "oc delete -f broker-route.yaml -n knative-eventing"
  pei "oc delete -f amq-topic.yaml -n bobbycar"
  exit
fi
