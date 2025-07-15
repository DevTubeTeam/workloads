```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

```
helm install kube-state-metrics prometheus-community/kube-state-metrics -n monitoring
```
```
helm repo add grafana https://grafana.github.io/helm-charts
helm install my-grafana grafana/grafana --namespace monitoring
```

Datasource: http://prometheus.monitoring.svc.cluster.local:9090