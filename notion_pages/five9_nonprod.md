<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.paragon.us.five9nonprod.net](https://dashboard.paragon.us.five9nonprod.net/infoz)</td>
	</tr>
</table>
### Deployment Changelog
<details>
<summary>Thu Oct 30, 2025</summary>
	- initial deployment with installer `2025.10.29` and app `2025.1027.0954-4550af89`
</details>
<details>
<summary>Wed Nov 5, 2025</summary>
	- upgraded app to `2025.1105.1542-8bd416f9`to fix [https://useparagon.atlassian.net/browse/SUP-968](https://useparagon.atlassian.net/browse/SUP-968) 
</details>
<details>
<summary>Tue Nov 25, 2025</summary>
	- increased `maxReplicas` on HPA for `connect` from 4 to 6
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
<summary>Tue Dec 16, 2025</summary>
	- upgraded app to `2025.1216.1236-565dcccf`
	- Installer version `2025.12.05`
	- Added the following values 
	```yaml
	connect:
	  autoscaling:
	    maxReplicas: 6
	
	worker-workflows:
	  env:
	    WORKER_WORKFLOWS_STREAMING_SIZE_THRESHOLD_MBS: 50
	```
</details>
<details>
<summary>Thu Dec 18, 2025</summary>
	- applied SUP-1099 changes to remove storage service account key
</details>
<details>
<summary>Tue Dec 23, 2025</summary>
	- manually set `WORKER_WORKFLOWS_STREAMING_SIZE_THRESHOLD_MBS` to `50` 
	```
	kubectl set env deployment/worker-workflows -e WORKER_WORKFLOWS_STREAMING_SIZE_THRESHOLD_MBS=50
	
	kubectl patch secret paragon-secrets --type='json' -p='[
	  {
	    "op": "replace",
	    "path": "/data/WORKER_WORKFLOWS_STREAMING_SIZE_THRESHOLD_MBS",
	    "value": "'$(echo -n "50" | base64)'"
	  }
	]'
	```
</details>
<details>
<summary>Tue Jan 13, 2026</summary>
	- upgraded app to `2026.0107.1419-7fdb2b73`
	- upgraded installer to `2025.12.16`
	- enabled TriggerKit charts
</details>
<details>
<summary>Fri Jan 30, 2026</summary>
	- upgraded app to `2026.0127.0753-2ed4c857`
	- upgraded installer to `2026.01.29`
	- deployed changes:
		- [SUP-1028](https://useparagon.atlassian.net/browse/SUP-1028) - Five9 (On-Prem) — GKE Cluster API Port Publicly Exposed Blocker
		- [SUP-1100](https://useparagon.atlassian.net/browse/SUP-1100) - Five9 — Instance Configuration Changes
		- [SUP-1219](https://useparagon.atlassian.net/browse/SUP-1219) - Five9 — Develop secure Grafana access plan
	- This required downtime while GKE cluster was rebuilt.
	- Slack threads:
		- [https://useparagon.slack.com/archives/C08LRJJMM34/p1769440468302459](https://useparagon.slack.com/archives/C08LRJJMM34/p1769440468302459) 
		- [https://useparagon.slack.com/archives/C08MBFD5X3J/p1768590177420949](https://useparagon.slack.com/archives/C08MBFD5X3J/p1768590177420949) 
</details>
<details>
<summary>Fri Feb 6, 2026</summary>
	- upgraded app to `2026.0205.1705-6bf496d0`
	- upgraded installer to `2026.02.05`
	- enabled redis TLS as final part of [SUP-1100](https://useparagon.atlassian.net/browse/SUP-1100)
	- downtime was required as all three redis clusters were destroyed and recreated
	- synced redis using script from here [https://useparagon.slack.com/archives/C01TE8V1JUF/p1770319400867349](https://useparagon.slack.com/archives/C01TE8V1JUF/p1770319400867349)
	- see additional complications here [https://useparagon.slack.com/archives/C0AD3278Y7R/p1770406567571539](https://useparagon.slack.com/archives/C0AD3278Y7R/p1770406567571539)
</details>
<details>
<summary>Wed Feb 11, 2026</summary>
	- patched custom streaming size 
		```
		k set env deploy/worker-workflows WORKER_WORKFLOWS_STREAMING_SIZE_THRESHOLD_MBS=30
		```
	- added following to `values.yaml` 
		```
		worker-workflows:
		  env:
		    WORKER_WORKFLOWS_STREAMING_SIZE_THRESHOLD_MBS: 30
		```
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>