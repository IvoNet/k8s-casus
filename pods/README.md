# Convenience pods


## Shell

A simple pod that logs a simple message to stdout every few seconds but also mounts a volume to the root of the node. This gives you a shell to interact with the cluster.

Example use:

```shell
k create -f pods/shell.yaml
k exec -it shell -- /bin/bash
# in the container... e.g.
ls -lsa /hostRoot/var/logs/containers
```

