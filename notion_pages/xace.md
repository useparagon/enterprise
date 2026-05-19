<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.paragon.integrations.xace.io/](https://dashboard.paragon.integrations.xace.io/)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.paragon.integrations.xace.io/](https://grafana.paragon.integrations.xace.io/)  (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Change Log
<details>
<summary>Fri Jul 18, 2025</summary>
	- initial installation with `2025.0717.0719-9f3a4f72` and installer `2025.6.4`
</details>
<details>
<summary>Mon Sep 22, 2025</summary>
	- upgraded EKS to `1.32` with expanded spot instance list
	- upgraded app to `2025.0918.1305-9abd3cb0`
	- upgraded installer to `2025.9.18`
	- updated `values.yaml` 
		```
		kafka-exporter:
		  replicaCount: 0
		```
</details>
<details>
<summary>Thu Oct 16, 2025</summary>
	- Patched flipt
		```
		kubectl patch hpa flipt -p '{"spec":{"minReplicas": 1, "maxReplicas": 5}}'
		```
		```
		kubectl patch deploy flipt --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"512Mi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"512Mi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"250m"},{"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits/cpu"}]'
		```
</details>
<details>
<summary>Fri Oct 17, 2025</summary>
	- applied new `flipt` patches
		```
		    Limits:
		      memory:  512Mi
		    Requests:
		      cpu:      500m
		      memory:   512Mi
		```
</details>
<details>
<summary>Thu Nov 6, 2025</summary>
	- upgraded app to `2025.1105.1542-8bd416f9`
	- upgraded installer to `2025.10.29`
</details>
<details>
<summary>Wed Nov 26, 2025</summary>
	```bash
	kubectl patch statefulset openobserve --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"public.ecr.aws/zinclabs/openobserve:v0.16.3"}]'
	
	kubectl set resources sts openobserve \
	  --requests=cpu=500m,memory=6Gi \
	  --limits=cpu=1,memory=6Gi
	
	kubectl set env sts/openobserve \
	  ZO_MEMORY_CACHE_MAX_SIZE=1024 \
	  ZO_MEMORY_CACHE_DATAFUSION_MAX_SIZE=256 \
	  ZO_MAX_FILE_SIZE_IN_MEMORY=128 \
	  ZO_COMPACT_MAX_FILE_SIZE=128 \
	  RUST_LOG=warn
	
	kubectl scale sts openobserve --replicas=1
	```
</details>
<details>
<summary>Thu Jan 15, 2026</summary>
	- upgraded app to `2026.0114.1351-424c08b4`
	- upgraded installer to `2025.12.16`
	- following values added to values.yaml
	```
	subchart:
	  cache-replay:
	    enabled: false
	  health-checker:
	    enabled: false
	  kafka-exporter:
	    enabled: false
	
	openobserve:
	  serviceAccount:
	    create: false
	```
</details>
<details>
<summary>Wed Feb 11, 2026</summary>
	- upgraded app to `2026.0211.1002-054bd856`
	- upgraded installer to `2026.02.09`
</details>
<details>
<summary>Wed Mar 11, 2026</summary>
	- Upgraded app to `2026.0309.1456-17d3e97d`
	- Upgraded installer to `2026.03.05`
	- Upgrade EKS to `v1.33`
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>