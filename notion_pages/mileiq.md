<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.paragon.mileiq.com](https://dashboard.paragon.mileiq.com)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.paragon.mileiq.com](https://grafana.paragon.mileiq.com)  (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Change Log
<details>
<summary>Tue May 20, 2025</summary>
	- initial installation with `2025.0529.1023-79895384` and installer `2025.5.29`
</details>
<details>
<summary>Mon Jun 9, 2025</summary>
	- upgraded app to`2025.0606.2150-7af2ac18`
	- upgraded installer to`2025.6.4`
	- fixed `EMAIL_FROM_ADDRESS: noreply@manage.mileiq.com`
</details>
<details>
<summary>Mon Jul 7, 2025</summary>
	- upgraded app to `2025.0705.1733-7c17d3b1`
</details>
<details>
<summary>Mon Aug 4, 2025</summary>
	- increased memory limit
		```
		kubectl patch deploy dashboard --type json -p='[{"op": "replace", "path": "/spec/template/spec/containe
		rs/0/resources/limits/memory", "value":"1Gi"}]'
		```
</details>
<details>
<summary>Wed Aug 13, 2025</summary>
	- upgraded app to `2025.0812.0630-0fd4be6a`
	- upgraded installer to `2025.7.10`
	- disabled `kafka-exporter` in `values.yaml`
		```
		kafka-exporter:
		  replicaCount: 0
		```
</details>
<details>
<summary>Mon Aug 25, 2025</summary>
	- upgraded app to `2025.0821.1256-ce51ff9c`
	- upgraded installer to `2025.8.7`
	- this required MileIQ to update our account permissions multiple times to avoid authorization errors
</details>
<details>
<summary>Mon Aug 25, 2025</summary>
	Reported Issue from CX after installation.
	To fix Ish ran the following commands:
	```
	helm get values paragon-on-prem --revision 9 | grep REDIS_URL
	kubectl get deployments -n paragon -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.annotations}{"\n"}{end}' | grep paragon-on-prem | awk '{print $1}' | xargs -I {} kubectl set env deployment/{} -e SYSTEM_REDIS_URL=<URL>
	kubectl get deployments -n paragon -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.annotations}{"\n"}{end}' | grep paragon-on-prem | awk '{print $1}' | xargs -I {} kubectl set env deployment/{} -e QUEUE_REDIS_URL=<URL>
	```
	Need to be sure we grab the proper `SYSTEM_REDIS_URL` and `QUEUE_REDIS_URL` for future deployments
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
	- upgraded k8s to 1.32 and set following to increase node group sizes 
		```
		k8s_min_node_count        = 20
		k8s_max_node_count        = 60
		k8s_spot_instance_percent = 50
		```
	- upgraded installer to `2025.10.29`
	- upgraded app to `2025.1105.1542-8bd416f9`
	- added following to `values.yaml` 
		```
		    ZEUS_JWT_SECRET: ea836f3f-af9c-4483-af26-185ed25879d3
		
		    AZURE_STORAGE_ACCOUNT_NAME: paragonmileiq3586w0qrfyi
		    AZURE_STORAGE_ACCOUNT_KEY: <redacted>
		
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
		
		openobserve:
		  env:
		    AZURE_STORAGE_ACCOUNT_NAME: paragonmileiq3586w0qrfyi
		    AZURE_STORAGE_ACCOUNT_KEY: <redacted>
		
		# new baseline values
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
		      memory: 4Gi
		    requests:
		      cpu: 1
		      memory: 4Gi
		```
</details>
<details>
<summary>Wed Nov 11, 2025</summary>
	- Increased OpenObserve memory 3Gi → 4Gi
		```
		kubectl patch sts openobserve --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"4Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"4Gi"}]'
		```
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
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>