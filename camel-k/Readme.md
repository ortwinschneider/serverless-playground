# OpenShift Serverless Integration Demo with Camel-K

In this demo we are going to
- Install the Camel-K operator in OpenShift
- We install a community Kamelet from the Kamalet Catalog
- Create a basic Camel-K Integration and deploy it to OpenShift
- Send Cloud Events from a Camel-K integration to a Knative Broker
- Deploy a Camel-K integration as a Knative Service and consume Cloud Events
- Create a Kamelet Binding consuming data from an AWS S3 bucket and sending it as Cloud Events to Knative 

```sh
      // Write your routes here, for example:
      from("timer:java?period=1000")
        .setHeader("Accept-Encoding").constant("identity")
        .to("netty-http:https://api.chucknorris.io/jokes/random")
        .unmarshal().json()
        .setBody().simple("${body[value]}")
        .setHeader("Content-Type").constant("text/plain")
        .to("knative:event/my.chucknorris.event.type?kind=Broker&name=mybroker");  
```

```sh
kamel run \
 --dev \
 --dependency camel:log \
 --dependency camel:jackson \
 --dependency camel:jsonpath \
 --trait knative.enabled=true \
 --profile knative \
 fruit-producer.yaml
```