# K0s

[K0s](https://k0sproject.io) is a single-binary Kubernetes distribution. It is very lightweight, and includes some niceties over its closest competitor, [k3s](https://k3s.io).

## Initial setup

- Install k0s with the [`install-k0s.sh` script](./install-k0s.sh)
- The script creates a kubectl config file at `~/.kube/config`
  - Somewhere in your `.bashrc` (or the files it sources on startup), add this: `export KUBECONFIG="$HOME/.kube/config"`
  - Now your `k0s` commands will not require sudo
- Check node networking with `k0s kubectl cluster-info`
  - If you see `localhost` or `127.0.0.1`, the cluster is not reachable from outside the node yet.
  - Create a cluster config with `sudo k0s config create > k0s.yaml`
  - Edit the `k0s.yaml` to set your cluster's IP:

    ```yaml
    spec:
      api:
        address: 192.168.1.xxx
    ```
  - After modifying the cluster's config, reinstall it with:
    - `sudo k0s stop`
    - `sudo k0s reset`
    - `sudo k0s install controller --single -c k0s.yaml`
    - `sudo k0s start`
    - Rebuild the admin config: `sudo k0s kubeconfig admin > ~/.kube/config`
    - Verify the cluster IP is correct now with `k0s kubectl cluster-info`
- Generate remote admin config (used to connect to the cluster on remote machines)
  - `sudo k0s kubeconfig admin > kubeconfig.yaml`
  - On a remote machine, create `~/.kube`
  - Copy the `kubeconfig.yaml` -> `~/.kube/config`
  - Test with `kubectl get nodes`
  - Remote machines only need `kubectl` installed, not `k0s`

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
| `k0s kubectl get deployments -A` | List all deployments |
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
| `sudo k0s config create > k0s.yaml` | Show Kubernetes cluster config on local node |
| `sudo k0s install controller --single -c k0s.yaml` | Reinstall/update cluster configuration from a file |
| `sudo k0s kubeconfig admin > kubeconfig.yaml` | Create a `kubeconfig.yaml` for the current node. Copy this file to other machines to access the node remotely |
| `k0s kubectl api-resources` | List all Kubernetes resource types & what the API can manage |
| `k0s kubectl get ns` | Show Kubernetes namespaces |

## Links

- [k0s home](https://k0sproject.io)
- [k0s docs](https://docs.k0sproject.io/v1.21.2+k0s.1/)
  - [k0s system requirements](https://docs.k0sproject.io/v1.21.2+k0s.1/system-requirements/)
  - [k0s Quickstart guide](https://docs.k0sproject.io/v1.21.2+k0s.1/install/)

