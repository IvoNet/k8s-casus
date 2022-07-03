# EFK


```shell
watch "kubectl -n efk get all,pv,pvc"
```

```shell
for i in *.yml; do echo $i;kubectl create -f $i;  done
```

```shell
for i in *.yml; do echo $i;kubectl delete -f $i;  done
```

```shell
k run logmonkey --image busybox --command -- /bin/sh -c 'i=0; while true; do echo "$i: Hello, are you collecting my data? $(date)"; i=$((i+1)); sleep 5; done'
```


```shell
k delete namespace efk
```