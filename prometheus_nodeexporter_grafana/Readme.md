
# 1. Cài đặt Node Exporter trên các server cần tracking (Ex: HUUNGHIAISH, PROD1)
```bash
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  -v "/etc/prometheus/:/textfile" \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host \
  --web.listen-address="0.0.0.0:9100" \
  --collector.textfile.directory=/textfile
```
# 2. Trường hợp private server: sử dụng Pushgateway  để pull metrics từ server private (Ex: DEV1, DEV2)
## push_metrics.py
```
import requests

# Địa chỉ của Node Exporter
node_exporter_url = "http://0.0.0.0:9100/metrics"

# Địa chỉ Pushgateway
pushgateway_url = "http://<103.111.22.22>:9091/metrics/job/node_exporter/instance/DEV1"

# Đọc dữ liệu từ Node Exporter
response = requests.get(node_exporter_url)
if response.status_code == 200:
    metrics = response.text
    # Push dữ liệu lên Pushgateway
    push_response = requests.post(pushgateway_url, data=metrics)
    if push_response.status_code == 200:
        print("Metrics pushed successfully!")
    else:
        print(f"Failed to push metrics: {push_response.status_code}")
else:
    print(f"Failed to scrape Node Exporter: {response.status_code}")
```
## Crontab
```bash
*/1 * * * * /usr/bin/python3 /home/deploy/scripts/push_metrics.py
```

## Cài đặt Pushgateway ở server Prometheus
```
docker run -d --name pushgatewaydev1 --restart unless-stopped -p 9091:9091 prom/pushgateway
docker run -d --name pushgatewaydev2 --restart unless-stopped -p 9092:9091 prom/pushgateway
```

## Update 
```
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'
    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  # Example job for node_exporter
  - job_name: 'node_exporter'
    static_configs:
      - targets:
          - '192.168.1.10:9100'
        labels:
          instance: 'HUUNGHIAISH'
     # push_gateway
      - targets:
          - '192.168.1.10:9091'
        labels:
          instance: 'DEV1'
      - targets:
          - '192.168.1.10:9092'
        labels:
          instance: 'DEV2'
```

# Grafana Alerting
## Notification template telegram
```
{{ if gt (len .Alerts.Firing) 0 }}
** 🔥 Warning **
{{ range .Alerts.Firing }}
- ** Server {{ .Labels.instance }} **: {{ .Labels.alertname }} ([View Detail]({{ .PanelURL }}&var-node={{ .Labels.instance }}), [Pause Notification]({{ .SilenceURL }}))
{{ end }}
{{ end }}
{{ if gt (len .Alerts.Resolved) 0 }}
** ✅ Resolved **
{{ range .Alerts.Resolved }}
- ** Server {{ .Labels.instance }} **: {{ .Labels.alertname }} ([View Detail]({{ .PanelURL }}&var-node={{ .Labels.instance }}), [Pause Notification]({{ .SilenceURL }}))
{{ end }}
{{ end }}
```
## Alert rules: Metrics browser
### Free Disk Space Below 10%
```
100 - ((node_filesystem_avail_bytes{job="node_exporter",mountpoint="/",fstype!="rootfs"} * 100) / node_filesystem_size_bytes{job="node_exporter",mountpoint="/",fstype!="rootfs"})
```
### CPU Usage Exceeds 90%
```
100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval])) by (instance))
```
### Memory Usage Exceeds 90%
```
(1 - (node_memory_MemAvailable_bytes{job="node_exporter"} / node_memory_MemTotal_bytes{ job="node_exporter"})) * 100
```