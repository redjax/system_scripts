# K0s

[K0s](https://k0sproject.io) is a single-binary Kubernetes distribution. It is very lightweight, and includes some niceties over its closest competitor, [k3s](https://k3s.io).

## Initial setup

- Install k0s with the [`install-k0s.sh` script](./install-k0s.sh)
- The script creates a kubectl config file at `~/.kube/config`
  - Somewhere in your `.bashrc` (or the files it sources on startup), add this: `export KUBECONFIG="$HOME/.kube/config"`
  - Now your `k0s` commands will not require sudo

## Commands

| Command | Description |
| ------- | ----------- |
| `k0s kubectl get nodes` | List all nodes in the cluster |
| `k0s kubectl describe node <node-name>` | List detailed node info |
| `k0s kubectl get pods` | List running pods in current namespace |
| `k0s kubectl get pods -A` | List all running pods |
| `k0s kubectl get pods -A -w` | Watch pods live |
| `k0s kubectl describe pod <pod-name>` | Describe a pod |
| `k0s kubectl logs <pod-name>` | View logs for a pod |
| `k0s kubectl logs -f <pod-name>` | Follow live logs for a pod |
| `k0s kubectl logs --previous <pod-name>` | Show logs from a crashed pod |
| `k0s kubectl exec -it <pod-name> -- sh` | Open a shell inside a container |
| `k0s kubectl get deployments` | List deployments |
| `k0s kubectl create deployment hello --image=nginx` | Create a deployment (example is nginx) |
| `k0s kubectl scale deployment hello --replicas=3` | Scale a deployment |
| `k0s kubectl rollout restart deployment hello` | Restart a deployment |
| `k0s kubectl rollout status deployment hello` | Check rollout status |
| `k0s kubectl rollout undo deployment hello` | Undo a rollout |
| `k0s kubectl get svc` || `k0s kubectl get services` | List services |
| `k0s kubectl expose deployment hello --port=80 --type=NodePort` | Expose a deployment as a service |
| `k0s kubectl apply -f app.yaml` | Apply a YAML config |
| `k0s kubectl delete -f app.yaml` | Delete a YAML config |
| `k0s kubectl get deployment hello -o yaml` | Get a deployment as a YAML file |
| `k0s kubectl edit deployment hello` | Open a live deployment in a text editor |
| `k0s kubectl get ns` | List namespaces |
| `k0s kubectl create namespace apps` | Create a namespace |
| `k0s kubectl -n apps get pods` | Select/use a namespace |
| `k0s kubectl get events -A` | Show cluster events |
| `k0s kubectl get events -A --sort-by=.metadata.creationTimestamp` | Sort cluster events by newest |
| `k0s kubectl top nodes` | Show node resource usages |
| `k0s kubectl top pods -A` | Show pod resource usages |
| `k0s kubectl cp file.txt podname:/tmp/file.txt` | Copy a file to a pod |
| `k0s kubectl cp podname:/tmp/file.txt .` | Copy a file from a pod |
| `k0s kubectl delete pod <pod-name>` | Delete a pod |
| `k0s kubectl delete deployment hello` | Delete a deployment |
| `k0s kubectl delete all --all` | Delete everything in a namespace |

## Links

- [k0s home](https://k0sproject.io)
- [k0s docs](https://docs.k0sproject.io/v1.21.2+k0s.1/)
  - [k0s system requirements](https://docs.k0sproject.io/v1.21.2+k0s.1/system-requirements/)
  - [k0s Quickstart guide](https://docs.k0sproject.io/v1.21.2+k0s.1/install/)

