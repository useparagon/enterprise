<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.integrations.nuwacom.ai/](https://dashboard.integrations.nuwacom.ai/)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.integrations.nuwacom.ai/](https://grafana.integrations.nuwacom.ai/)  (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Change Log
<details>
<summary>Thu Jul 17, 2025</summary>
	- initial installation with `2025.0717.0719-9f3a4f72` and installer `2025.7.17`
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
<summary>Thu Oct 23, 2025</summary>
	- upgraded AKS to `1.32`
	- upgraded installer to `2025.10.23`
	- upgraded app to `2025.1021.1745-23e77d7d`
	- add following to `values.yaml` 
		```
		    ZEUS_JWT_SECRET: 21dacd5a-f951-40ea-9731-cf8d93c3f535
		
		cache-replay:
		  autoscaling:
		    enabled: false
		  replicaCount: 0
		
		health-checker:
		  autoscaling:
		    enabled: false
		  replicaCount: 0
		
		kafka-exporter:
		  autoscaling:
		    enabled: false
		  replicaCount: 0
		
		flipt:
		  autoscaling:
		    minReplicas: 1
		    maxReplicas: 5
		  resources:
		    limits:
		      cpu: 1000m
		      memory: 512Mi
		    requests:
		      cpu: 500m
		      memory: 512Mi
		
		# new defaults for worker-workflows
		worker-workflows:
		  autoscaling:
		    enabled: false
		  replicaCount: 4
		  env:
		    WORKER_SHARED_SERVICE_MIN_INSTANCES: 4
		    WORKER_SHARED_SERVICE_MAX_INSTANCES: 30
		    WORKER_WORKFLOWS_MAX_QUEUES_PER_HOST: 4
		    WORKER_SHARED_AUTOSCALING_DISABLED: false
		    WORKER_WORKFLOWS_PARALLEL_PROCESSING_COUNT: 1
		    WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT: 2
		    WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT: 0
		  resources:
		    limits:
		      memory: 4Gi
		    requests:
		      # TODO this wouldn't schedule with 2
		      cpu: 1
		      memory: 4Gi
		```
</details>
<details>
<summary>Thu Nov 20, 2025</summary>
	- upgraded `infra` workspace to enable node maintenance window
</details>
<details>
<summary>Wed 26 Nov, 2025</summary>
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
	  AZURE_STORAGE_ACCOUNT_NAME=<redacted> \
	  AZURE_STORAGE_ACCOUNT_KEY=<redacted> \
	  RUST_LOG=warn
	
	kubectl scale sts openobserve --replicas=1
	```
</details>
<details>
<summary>Tue Dec 16, 2025</summary>
	`EMAIL_FROM_ADDRESS` changed from [<span underline="true">dev@nuwacom.ai</span>](mailto:dev@nuwacom.ai) → [<span underline="true">noreply@nuwacom.ai</span>](mailto:noreply@nuwacom.ai)
	[https://useparagon.atlassian.net/browse/SUP-1124](https://useparagon.atlassian.net/browse/SUP-1124) 
	```
	for d in account pheme zeus; do   kubectl set env deployment/$d EMAIL_FROM_ADDRESS=noreply@nuwacom.ai; done
	```
</details>
<details>
<summary>Tue Jan 13, 2026</summary>
	- upgraded installer to `2025.12.16`
	- upgraded app to `2026.0107.1419-7fdb2b73`
	- add following to `values.yaml` 
	```
	global:
	  env:
	    EMAIL_FROM_ADDRESS: noreply@nuwacom.ai
	
	openobserve:
	  serviceAccount:
	    create: true
	
	subchart:
	  cache-replay:
	    enabled: false
	  kafka-exporter:
	    enabled: false
	  health-checker:
	    enabled: false
	```
</details>
<details>
<summary>Tue Jan 13, 2026</summary>
	- upgraded installer to `2026.02.03`
	- upgraded app to `2026.0205.0810-fb94caf9` (worker-auditlogs)
</details>
<details>
<summary>Mon Mar 9, 2025</summary>
	- upgraded installer to `2026.03.05`
	- upgraded app to `2026.0305.1216-e6507ca1`
	- added `CACHE_REDIS_URL` to `values.yaml`
	- changed following in `infra/vars.auto.tfvars` 
		```
		k8s_version = "1.33.5"
		postgres_redundant = true
		```
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>