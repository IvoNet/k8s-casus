# Elastic search

```shell
k get all,secret
```

```shell
kubectl api-resources --namespaced=true --no-headers
```
```shell
kubectl api-resources --namespaced=true --no-headers| awk '{print $1}'|sort
```

## Logging dummy pod

```shell
k run logmonkey --image busybox --command -- /bin/sh -c 'i=0; while true; do echo "$i: Hello, are you collecting my data? $(date)"; i=$((i+1)); sleep 5; done'
```

```shell
k delete pod logmonkey
```

## Elastic search directly

port-forwarding to the pod and then use as localhost resource.

https://gist.github.com/ruanbekker/e8a09604b14f37e8d2f743a87b930f93

```shell
k port-forward service/elasticsearch-master 9200:9200
```

```shell
curl -XGET 'http://localhost:9200/_cluster/health?level=indices&pretty'
```

```shell
curl -XGET 'http://localhost:9200/_cluster/health?level=shards&pretty'
```

```shell
curl -XGET http://localhost:9200/_cat/nodes?v
```

```shell
curl -XGET http://localhost:9200/_cat/master?v
```

```shell
curl -XGET http://localhost:9200/_cat/indices?v
```

# Get loadbalancer IP

Simplest way to get the loadbalancer IP is to use the `kubectl get svc` command and have a look at the `LoadBalancer` > `EXTERNAL-IP` field.

Others:

```shell
k get svc --no-headers|grep LoadBalancer|awk '{print $1}'|xargs -I{} kubectl -n $NS get svc {} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
```shell
k get service --no-headers | grep LoadBalance | awk '{print $4}'
```

# Export default namespace

```shell
for n in $(kubectl get -o=name pvc,configmap,serviceaccount,secret,ingress,service,deployment,statefulset,hpa,job,cronjob)
do
    mkdir -p $(dirname $n)
    kubectl get -o yaml $n > $n.yaml
done
```

```shell
#!/usr/bin/env bash
ROOT=./clusterstate
while read -r resource
do
    echo "  scanning resource '${resource}'"
    while read -r namespace item x
    do
        mkdir -p "${ROOT}/${namespace}/${resource}"        
        echo "    exporting item '${namespace} ${item}'"
        kubectl get "$resource" -n "$namespace" "$item" -o yaml > "${ROOT}/${namespace}/${resource}/$item.yaml" &
    done < <(kubectl get "$resource" --all-namespaces 2>&1  | tail -n +2)
done < <(kubectl api-resources --namespaced=true 2>/dev/null | grep -v "events" | tail -n +2 | awk '{print $1}')
wait
```