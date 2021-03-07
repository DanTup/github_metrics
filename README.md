# GitHub Issue Metrics for Prometheus

A small webserver that collects some issue metrics from GitHub and serves them up in a format for Prometheus. I created this as a simple way to get some simple stats of issue counts (by labels) in a Grafana instance I'm running locally via [microk8s](https://microk8s.io/) using the [prometheus addon](https://microk8s.io/docs/addons#heading--list).

## Usage

The easiest way to test it out is using `docker run`. Use `--repo` to pass the GitHub repository in the form user/repo or org/repo and `--label-prefix` to set labels or prefixes to bucket issues by (these should ideally be non-overlapping).

```
docker run -p 4040:4040 dantup/github_metrics \
    --repo="Dart-Code/Dart-Code" \
    --label-prefix="awaiting info" \
    --label-prefix="blocked" \
    --label-prefix="upstream" \
    --label-prefix="is enhancement" \
    --label-prefix="is bug" \
    --label-prefix="is testing"
```

This should output:

```
Listening on http://0.0.0.0:4040/metrics
```

Accessing `/metrics` will produce a response like:

```
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="awaiting info"} 15
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="blocked"} 29
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="upstream"} 1
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="is enhancement"} 59
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="is bug"} 22
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="is testing"} 1
github_issue_metrics_labels{repo="Dart-Code/Dart-Code", label="other"} 5
github_issue_metrics_open{repo="Dart-Code/Dart-Code"} 132
github_issue_metrics_closed{repo="Dart-Code/Dart-Code"} 2549
```

I (ab)use Grafana/Prometheus ServiceMonitor in Kubernetes to set the whole thing up using just a little YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-metrics-deployment
  labels:
    app: github-metrics-deployment
spec:
  selector:
    matchLabels:
      app: github-metrics
  template:
    metadata:
      labels:
        app: github-metrics
    spec:
      containers:
        - name: github-metrics
          image: dantup/github_metrics
          args: ["--repo=Dart-Code/Dart-Code", "--label-prefix=awaiting info", "--label-prefix=blocked", "--label-prefix=upstream", "--label-prefix=is enhancement", "--label-prefix=is bug", "--label-prefix=is testing"]
          ports:
            - containerPort: 4040

---

apiVersion: v1
kind: Service
metadata:
  name: github-metrics-service
  labels:
    app: github-metrics-service
spec:
  selector:
    app: github-metrics
  ports:
    - name: metrics
      port: 4040

---

apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: github-metrics-monitor
  namespace: monitoring
spec:
  endpoints:
    - interval: 5m
      port: metrics
      path: /metrics
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: github-metrics-service
```
