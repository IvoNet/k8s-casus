# EFK

- Elasticsearch
- Filebeat
- Kibana

# Commands

```shell
k create namespace efk
```
```shell
export NS=efk
```

# Elasticsearch
Elastic search has elements that are [stateful](https://spot.io/blog/kubernetes-tutorial-successful-deployment-of-elasticsearch/#:~:text=Several%20of%20the%20Elasticsearch%20components,way%20using%20a%20load%20balancer)

- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

This is the minimal change based on the definition given by the k8s site

- possible Failures 

```text
For complete error details, refer to the log at /usr/share/elasticsearch/logs/docker-cluster.log\n"}
java.lang.IllegalStateException: failed to obtain node locks, tried [/usr/share/elasticsearch/data]; maybe these locations are not writable or multiple nodes were started on the same data path?
Likely root cause: java.nio.file.NoSuchFileException: /usr/share/elasticsearch/data/node.lock
	at java.base/sun.nio.fs.UnixException.translateToIOException(UnixException.java:92)
	at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:106)
	at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:111)
	at java.base/sun.nio.fs.UnixPath.toRealPath(UnixPath.java:825)
	at org.apache.lucene.core@9.2.0/org.apache.lucene.store.NativeFSLockFactory.obtainFSLock(NativeFSLockFactory.java:94)
	at org.apache.lucene.core@9.2.0/org.apache.lucene.store.FSLockFactory.obtainLock(FSLockFactory.java:43)
	at org.apache.lucene.core@9.2.0/org.apache.lucene.store.BaseDirectory.obtainLock(BaseDirectory.java:44)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.env.NodeEnvironment$NodeLock.<init>(NodeEnvironment.java:223)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.env.NodeEnvironment$NodeLock.<init>(NodeEnvironment.java:198)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.env.NodeEnvironment.<init>(NodeEnvironment.java:277)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.node.Node.<init>(Node.java:438)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.node.Node.<init>(Node.java:300)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.bootstrap.Bootstrap$5.<init>(Bootstrap.java:230)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.bootstrap.Bootstrap.setup(Bootstrap.java:230)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:333)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:224)
	at org.elasticsearch.server@8.3.1/org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:67)
For complete error details, refer to the log at /usr/share/elasticsearch/logs/docker-cluster.log
ERROR: Elasticsearch did not exit normally - check the logs at /usr/share/elasticsearch/logs/docker-cluster.log

ERROR: Elasticsearch exited unexpectedly
```

To fix this we need to add an initContainer to the StatefulSet that corrects the rights of the container

```yaml
     
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
```

- this seemed to go alright but it failes on `vm.max_map_count`

```text
vice","elasticsearch.node.name":"es-cluster-0","elasticsearch.cluster.name":"docker-cluster"}
{"@timestamp":"2022-07-03T12:47:49.229Z", "log.level": "INFO", "message":"bound or publishing to a non-loopback address, enforcing bootstrap checks", "ecs.version": "1.2.0","service.name":"ES_ECS","event.dataset":"elasticsearch.server","process.thread.name":"main","log.logger":"org.elasticsearch.bootstrap.BootstrapChecks","elasticsearch.node.name":"es-cluster-0","elasticsearch.cluster.name":"docker-cluster"}
bootstrap check failure [1] of [3]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
bootstrap check failure [2] of [3]: the default discovery settings are unsuitable for production use; at least one of [discovery.seed_hosts, discovery.seed_providers, cluster.initial_master_nodes] must be configured
```

- so fix that in an init container too

```yaml
      initContainers:
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
```

- failure on ssl security

```text
.version": "1.2.0","service.name":"ES_ECS","event.dataset":"elasticsearch.server","process.thread.name":"main","log.logger":"org.elasticsearch.bootstrap.BootstrapChecks","elasticsearch.node.name":"es-cluster-0","elasticsearch.cluster.name":"docker-cluster"}
bootstrap check failure [1] of [2]: the default discovery settings are unsuitable for production use; at least one of [discovery.seed_hosts, discovery.seed_providers, cluster.initial_master_nodes] must be configured
bootstrap check failure [2] of [2]: Transport SSL must be enabled if security is enabled. Please set [xpack.security.transport.ssl.enabled] to [true] or disable security by setting [xpack.security.enabled] to [false]
ERROR: Elasticsearch did not exit normally - check the logs at /usr/share/elasticsearch/logs/docker-cluster.log
{"@timestamp":"2022-07-03T13:29:27.932Z", "log.level": "INFO", "message":"stopping ...", "ecs.version": "1.2.0","service.name":"ES_ECS","event.dataset":"elasticsearch.server","process.thread.name":"Thread-1","log.logger":"org.elasticsearch.node.Node","elasticsearch.node.name":"es-cluster-0","elasticsearch.cluster.name":"docker-cluster"}
{"@timestamp":"2022-07-03T13:29:27.992Z", "log.level": "INFO", "message":"stopped", "ecs.version": "1.2.0","service.name":"ES_ECS","event.dataset":"elasticsearch.
...

ERROR: [2] bootstrap checks failed. You must address the points described in the following [2] lines before starting Elasticsearch.
```

- Editted the StatefulSet and added the env setting `xpack.security.enabled` to `"false"`

```bash
k edit statefulset.apps/es-cluster
# add the following to the container
       env:
          - name: xpack.security.enabled
            value: "false"
# exit vi
#  kill the pods
k delete pod/es-cluster-0
k delete pod/es-cluster-1
k delete pod/es-cluster-2
```

- now it fails with...

```text
ootstrapChecks","elasticsearch.node.name":"es-cluster-0","elasticsearch.cluster.name":"docker-cluster"}
bootstrap check failure [1] of [1]: the default discovery settings are unsuitable for production use; at least one of [discovery.seed_hosts, discovery.seed_providers, cluster.initial_master_nodes] must be configured
ERROR: Elasticsearch did not exit normally - check the logs at /usr/share/elasticsearch/logs/docker-cluster.log
{"@timestamp":"2022-07-03T13:36:01.916Z", "log.level": "INFO", "message":"stopping ...", "ecs.version": "1.2.0","service.name":"ES_ECS","event.dataset":"elasticsearch.server","process.thread.name":"Thread-1","log.logger":"org.elasticsearch.node.Node","elasticsearch.node.name":"es-cluster-0","elasticsearch.cluster.name":"docker-cluster"}
{"@timestamp":"2022-07-03T13:36:01.990Z", "log.level": "INFO", "message":"stopped", "ecs.version": "1.2.0","service.name":"ES_ECS","event.dataset":"elasticse
```

- so lets configure `discovery.seed_hosts`, `discovery.seed_providers`, `cluster.initial_master_nodes`
- google /  https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery-settings.html
- resulting in my situation in see the elasticsearch.yml files


```shell
k delete namespace efk && k create namespace efk 
```

- now they all seem to be running :-)

# Filebeat

Now that we have elasticsearch running lets make the container logs available through filebeat

- With ElasticSearch I tried it all on my own and then I got smarter :-) not much but some smarter
- I searched for "deploy filebeat kubernetes" and found this
- `curl -L -O https://raw.githubusercontent.com/elastic/beats/8.3/deploy/kubernetes/filebeat-kubernetes.yaml` [here](https://www.elastic.co/guide/en/beats/filebeat/current/running-on-kubernetes.html)
- I adjusted the yaml to this:
    - removed some parameters and changed the startup params
    - enabled http startup



# Kibana

Now that we have elasticsearch running and a filebeat lets expose it in kibana

- create a kibana deployment
- https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-kibana.html -> did not work for me so do it ourselves
- image: https://www.docker.elastic.co/r/kibana
- deployment: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

change it to kibana

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: efk
  labels:
    app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:8.3.1
        ports:
        - containerPort: 5601
```

- now expose it

```shell
k expose deployment kibana --port=80 --target-port=5601 --type=LoadBalancer
k get svc -w
```

- Zodra je de site ziet .... kan een paar minuten duren
- Nu heb je alleen nog niks te zien...


```shell
k delete namespace efk
```
