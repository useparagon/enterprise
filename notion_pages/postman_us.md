<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[http://dashboard.us.integrations.postmancloud.com/](http://dashboard.us.integrations.postmancloud.com/infoz)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[http://grafana.us.integrations.postmancloud.com/](http://grafana.us.integrations.postmancloud.com/)  (shared creds in 1Password)</td>
	</tr>
</table>
# Change Log
<details>
<summary>Mon Sep 29, 2025</summary>
	- initial installation with `2025.0924.0834-e3dc2d31`
</details>
<details>
<summary>Mon Oct 6, 2025</summary>
	- destroyed initial installation and redeployed removing all `beta` references
	- installation with app `2025.1001.1021-edf4231b` and installer `2025.9.18`
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
<summary>Fri Oct 31, 2025</summary>
	- upgraded installer to `2025.10.29`
	- upgraded app to `2025.1027.0954-4550af89`
	- updated `values.yaml` with new baseline defaults 
		```
		# new baseline defaults
		flipt:
		  autoscaling:
		    minReplicas: 1
		    maxReplicas: 5
		  resources:
		    limits:
		      cpu: 2
		      memory: 512Mi
		    requests:
		      cpu: 500m
		      memory: 512Mi
		
		# new baseline defaults
		worker-workflows:
		  autoscaling:
		    enabled: false
		  replicaCount: 4
		  env:
		    WORKER_SHARED_AUTOSCALING_DISABLED: false
		    WORKER_SHARED_SERVICE_MAX_INSTANCES: 30
		    WORKER_SHARED_SERVICE_MIN_INSTANCES: 4
		    WORKER_WORKFLOWS_MAX_QUEUES_PER_HOST: 4
		    WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT: 0
		    WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT: 2
		    WORKER_WORKFLOWS_PARALLEL_PROCESSING_COUNT: 1
		  resources:
		    limits:
		      cpu: 4
		      memory: 4Gi
		    requests:
		      cpu: 2
		      memory: 4Gi
		```
</details>
<details>
<summary>Mon Nov 10. 2025</summary>
	- upgraded installer to `2025.11.10`
	- upgraded app to `2025.1105.1542-8bd416f9`
	- removed `flipt`overrides from `values.yaml`
</details>
<details>
<summary>Thu Nov 13, 2025</summary>
	- upgraded app to `2025.1112.1635-2fc4e450`
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
<summary>Mon Dec 1, 2025</summary>
	- upgraded app to `2025.1125.1416-2ee43c35`
	- updated `values.yaml` with 
		```
		openobserve:
		  image:
		    tag: v0.20.1
		  resources:
		    limits:
		      cpu: 1
		      memory: 6Gi
		    requests:
		      cpu: 500m
		      memory: 6Gi
		  replicaCount: 1
		  env:
		    RUST_LOG: warn
		    ZO_ALLOW_USER_DEFINED_SCHEMAS: true
		    ZO_COMPACT_MAX_FILE_SIZE: 128
		    ZO_MAX_FILE_SIZE_IN_MEMORY: 128
		    ZO_MEMORY_CACHE_DATAFUSION_MAX_SIZE: 256
		    ZO_MEMORY_CACHE_MAX_SIZE: 1024
		```
</details>
<details>
<summary>Wed Dec 17, 2025</summary>
	- upgraded installer to `2025.12.05`
	- upgraded app to `2025.1216.1236-565dcccf`
</details>
<details>
<summary>Mon Jan 12, 2026</summary>
	- upgraded installer to `2025.12.16`
	- upgraded app to `2026.0107.1419-7fdb2b73` (TriggerKit)
	- The following values were added to `values.yaml` 
	```yaml
	openobserve:
	  serviceAccount:
	    create: false
	```
</details>
<details>
<summary>Mon Feb 9, 2026</summary>
	- upgraded app to `2026.0209.0703-41b779f5`
	- upgraded installer to `2026.02.06`
</details>
<details>
<summary>Mon Mar 9, 2026</summary>
	- Upgraded app to `2026.0305.1216-e6507ca1`
	- Upgraded installer to `2026.03.05`
	- Upgrade EKS to `v1.33`
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>