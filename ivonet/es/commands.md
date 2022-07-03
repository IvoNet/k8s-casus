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
```shell
```
```shell
```
```shell
```
```shell
```
```shell
```
```shell
```
```shell
```
```shell
k delete namespace efk
```
