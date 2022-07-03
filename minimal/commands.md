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
```shell
k create poddisruptionbudget es-master-pdb --selector="app=es-master" --max-unavailable 1 --dry-run=client -o yaml
```
# Elasticsearch
Elastic search has elements that are [stateful](https://spot.io/blog/kubernetes-tutorial-successful-deployment-of-elasticsearch/#:~:text=Several%20of%20the%20Elasticsearch%20components,way%20using%20a%20load%20balancer)

- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
    - port: 80
      name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx # has to match .spec.template.metadata.labels
  serviceName: "nginx"
  replicas: 3 # by default is 1
  minReadySeconds: 10 # by default is 0
  template:
    metadata:
      labels:
        app: nginx # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 10
      containers:
        - name: nginx
          image: k8s.gcr.io/nginx-slim:0.8
          ports:
            - containerPort: 80
              name: web
          volumeMounts:
            - name: www
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: www
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: "my-storage-class"
        resources:
          requests:
            storage: 1Gi
```

change it to

```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: efk
  labels:
    app: elasticsearch
spec:
  ports:
  - port: 9200
    name: api
  - port: 9300
    name: inter-node
  clusterIP: None # Headless service
  selector:
    app: elasticsearch
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: efk
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.3.1
        ports:
        - containerPort: 9200
          name: api
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data        
  volumeClaimTemplates:
  - metadata:
      name: es-data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
```

This is the minimal change based on the definition given by the k8s site

- it will fail with something like 

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
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: efk
  labels:
    app: elasticsearch
spec:
  ports:
  - port: 9200
    name: api
  - port: 9300
    name: inter-node
  clusterIP: None # Headless service
  selector:
    app: elasticsearch
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: efk
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.3.1
        ports:
        - containerPort: 9200
          name: api
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data        
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: es-data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
```

- In this case I changed it but it kept on failing and I did not understand by I had forgotten to remove the pv,pvc's created by the volumeClaimTemplate
- fixed it with:

```shell
k delete namespace efk && k create namespace efk
k create -f es-ss2.yml
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
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: efk
  labels:
    app: elasticsearch
spec:
  ports:
  - port: 9200
    name: api
  - port: 9300
    name: inter-node
  clusterIP: None # Headless service
  selector:
    app: elasticsearch
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: efk
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.3.1
        ports:
        - containerPort: 9200
          name: api
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data        
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
volumeClaimTemplates:
  - metadata:
      name: es-data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
```

- this seemed to go alright at first but it failes on ssl security

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
- resulting in my situation in

```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: efk
  labels:
    app: elasticsearch
spec:
  ports:
  - port: 9200
    name: api
  - port: 9300
    name: inter-node
  clusterIP: None # Headless service
  selector:
    app: elasticsearch
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: efk
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.3.1
        ports:
        - containerPort: 9200
          name: api
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data        
        env:
          - name: cluster.name
            value: k8s-logs
          - name: node.name
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: discovery.seed_hosts 
            value: "es-cluster-0.elasticsearch,es-cluster-1.elasticsearch,es-cluster-2.elasticsearch"
          - name: cluster.initial_master_nodes 
            value: "es-cluster-0,es-cluster-1,es-cluster-2"
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx512m"
          - name: xpack.security.enabled
            value: "false"
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
  volumeClaimTemplates:
  - metadata:
      name: es-data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
```

```shell
k delete namespace efk && k create namespace efk && k create -f ubuntu.yml && k create -f es-ss3.yml
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

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: efk
  labels:
    k8s-app: filebeat
data:
  filebeat.yml: |-
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"

    # To enable hints based autodiscover, remove `filebeat.inputs` configuration and uncomment this:
    #filebeat.autodiscover:
    #  providers:
    #    - type: kubernetes
    #      node: ${NODE_NAME}
    #      hints.enabled: true
    #      hints.default_config:
    #        type: container
    #        paths:
    #          - /var/log/containers/*${data.kubernetes.container.id}.log

    processors:
      - add_cloud_metadata:
      - add_host_metadata:

    cloud.id: ${ELASTIC_CLOUD_ID}
    cloud.auth: ${ELASTIC_CLOUD_AUTH}

    output.elasticsearch:
      hosts: ['${ELASTICSEARCH_HOST:elasticsearch}:${ELASTICSEARCH_PORT:9200}']
      username: ${ELASTICSEARCH_USERNAME}
      password: ${ELASTICSEARCH_PASSWORD}
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: efk
  labels:
    k8s-app: filebeat
spec:
  selector:
    matchLabels:
      k8s-app: filebeat
  template:
    metadata:
      labels:
        k8s-app: filebeat
    spec:
      serviceAccountName: filebeat
      terminationGracePeriodSeconds: 30
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.3.1
        args: [
          "-e", "-E", "http.enabled=true"
        ]
        env:
        - name: ELASTICSEARCH_HOST
          value: elasticsearch
        - name: ELASTICSEARCH_PORT
          value: "9200"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: NODE_NAME
        securityContext:
          runAsUser: 0
          # If using Red Hat OpenShift uncomment this:
          #privileged: true
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - name: config
          mountPath: /etc/filebeat.yml
          readOnly: true
          subPath: filebeat.yml
        - name: data
          mountPath: /usr/share/filebeat/data
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: config
        configMap:
          defaultMode: 0640
          name: filebeat-config
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: varlog
        hostPath:
          path: /var/log
      # data folder stores a registry of read status for all files, so we don't send everything again on a Filebeat pod restart
      - name: data
        hostPath:
          # When filebeat runs as non-root user, this directory needs to be writable by group (g+w).
          path: /var/lib/filebeat-data
          type: DirectoryOrCreate
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: efk
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: filebeat
  namespace: efk
subjects:
  - kind: ServiceAccount
    name: filebeat
    namespace: efk
roleRef:
  kind: Role
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: filebeat-kubeadm-config
  namespace: efk
subjects:
  - kind: ServiceAccount
    name: filebeat
    namespace: efk
roleRef:
  kind: Role
  name: filebeat-kubeadm-config
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
  labels:
    k8s-app: filebeat
rules:
- apiGroups: [""] # "" indicates the core API group
  resources:
  - namespaces
  - pods
  - nodes
  verbs:
  - get
  - watch
  - list
- apiGroups: ["apps"]
  resources:
    - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources:
    - jobs
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: filebeat
  # should be the namespace where filebeat is running
  namespace: efk
  labels:
    k8s-app: filebeat
rules:
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: filebeat-kubeadm-config
  namespace: efk
  labels:
    k8s-app: filebeat
rules:
  - apiGroups: [""]
    resources:
      - configmaps
    resourceNames:
      - kubeadm-config
    verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: efk
  labels:
    k8s-app: filebeat
---
```

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
