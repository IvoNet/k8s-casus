# Restore

```shell
for i in `find ./backup_DATE_HERE/NAMESPACE_HERE/ -name "*.yaml"`; do echo $i;kubectl create -f $i;  done
```