NOTE: This uses the Upsales Terraform Cloud account. This requires a user token in the `main.tf` files. Upsales may have to provide new tokens periodically.
<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.paragon.upsales.com](https://dashboard.paragon.upsales.com)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.paragon.upsales.com](https://grafana.paragon.upsales.com)  (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Change Log
<details>
<summary>Tue May 20, 2025</summary>
	- initial installation with `2025.0519.0415-5de440eb` and installer `2025.5.13`
</details>
<details>
<summary>Thu May 22, 2025</summary>
	- deployed feature flags from [https://github.com/useparagon/feature-flags/blob/enterprise/upsales/production/features.yml](https://github.com/useparagon/feature-flags/blob/enterprise/upsales/production/features.yml)
	- removed these values from `values.yaml`
		```
		    FLIPT_STORAGE_TYPE: local
		    FLIPT_STORAGE_LOCAL_PATH: /etc/flipt
		```
</details>
<details>
<summary>Thu Jun 26, 2025</summary>
	- upgraded app to `2025.0624.2344-ec77ad33`
	- upgraded installer to `2025.6.4`
</details>
<details>
<summary>Tue Jul 22, 2025</summary>
	- zeus cpu + memory limit upgrade
	```
	kubectl patch deploy zeus --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"2Gi"}]'
	kubectl patch deploy zeus --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"1"}]'
	```
</details>
<details>
<summary>Fri Jul 25, 2025</summary>
	- patched max replicas for zeus from 4 to 6
	```
	kubectl patch hpa zeus -p '{"spec":{"minReplicas": 2, "maxReplicas": 6}}'
	```
</details>
<details>
<summary>Thu Aug 7, 2025</summary>
	- upgraded app to `2025.0807.1112-0b30ce16`
	- upgraded installer to `2025.7.10`
	- updated local `features.yml` to enable event logs
</details>
<details>
<summary>Thu Sep 4, 2025</summary>
	- increased zeus resources 
		```
		kubectl patch deploy zeus --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"750m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"500m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"1.5Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"1.5Gi"}]'
		```
</details>
<details>
<summary>Sat Sep 6, 2025</summary>
	- increased worker-workflows and zeus resources 
		```
		kubectl patch deploy worker-workflows --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"750m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"750m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"3Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"3Gi"}]'
		kubectl patch deploy zeus --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"750m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"500m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"2Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"2Gi"}]'
		```
</details>
<details>
<summary>Wed Sep 10, 2025</summary>
	- increased worker-workflows memory to 3.5Gi
		```
		kubectl patch deploy worker-workflows --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"3.5Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"3.5Gi"}]'
		```
</details>
<details>
<summary>Wed Sep 12, 2025</summary>
	- patched memory of worker-workflows to 4Gi
		```
		kubectl patch deploy worker-workflows --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"4Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"4Gi"}]'
		```
</details>
<details>
<summary>Tue Oct 7, 2025</summary>
	- upgraded EKS to `1.32` with expanded spot instance list
	- upgraded installer to `2025.10.7`
	- upgraded app to `2025.1001.1021-edf4231b`
	- added following to `values.yaml`
		```
		    ZEUS_JWT_SECRET: 65870bbe-27e4-4e4a-bc56-577db15cbf5e
		
		kafka-exporter:
		  autoscaling:
		    enabled: false
		  replicaCount: 0
		
		openobserve:
		  env:
		    ZO_MEMORY_CACHE_ENABLED: true
		    ZO_MEMORY_CACHE_MAX_SIZE: 512
		    ZO_MEMORY_CACHE_DATAFUSION_MAX_SIZE: 256
		    ZO_MAX_FILE_SIZE_IN_MEMORY: 64
		    ZO_FILE_MOVE_THREAD_NUM: 1
		    ZO_COMPACT_FAST_MODE: false
		    ZO_COMPACT_MAX_FILE_SIZE: 128
		    RUST_LOG: error
		  resources:
		    limits:
		      cpu: 2
		      memory: 3Gi
		    requests:
		      cpu: 1
		      memory: 3Gi
		
		worker-workflows:
		  resources:
		    limits:
		      cpu: 1000m
		      memory: 4Gi
		    requests:
		      cpu: 750m
		      memory: 4Gi
		```
</details>
<details>
<summary>Tue Oct 14,2025</summary>
	- Increased flipt deploy cpu request and limit
		```
		kubectl patch deploy flipt --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"400m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"200m"}]'
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
<summary>Mon Oct 27, 2025</summary>
	Manually set `EVENT_LOG_ENABLED` flag to true
	```
	diff --git a/production/features.yml b/production/features.yml
	index a6463a7..8768e74 100644
	--- a/production/features.yml
	+++ b/production/features.yml
	   - key: EVENT_LOG_ENABLED
	     type: BOOLEAN_FLAG_TYPE
	+    enabled: true
	```
</details>
### See [https://useparagon.atlassian.net/browse/SUP-948](https://useparagon.atlassian.net/browse/SUP-948)
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
SEV-427: [https://useparagon.slack.com/archives/C0A1YAS4S20](https://useparagon.slack.com/archives/C0A1YAS4S20)
<details>
<summary>Fri Dec 5, 2025</summary>
	```bash
	kubectl patch deploy zeus --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"4096Mi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"4096Mi"}]'
	```
</details>
SEV-432: [https://useparagon.slack.com/archives/C0A36983C3S/p1765236805755519](https://useparagon.slack.com/archives/C0A36983C3S/p1765236805755519)
<details>
<summary>Mon Dec 8, 2025</summary>
	```bash
	kubectl set env deploy/worker-workflows \
	    WORKER_SHARED_AUTOSCALING_DISABLED=false \
	    WORKER_SHARED_SERVICE_MAX_INSTANCES=30 \
	    WORKER_SHARED_SERVICE_MIN_INSTANCES=4 \
	    WORKER_WORKFLOWS_MAX_QUEUES_PER_HOST=4 \
	    WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT=0 \
	    WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT=2 \
	    WORKER_WORKFLOWS_PARALLEL_PROCESSING_COUNT=1
	```
	```bash
	kubectl delete hpa worker-workflows
	```
</details>
<details>
<summary>Mon Dec 9, 2025</summary>
	```bash
	kubectl patch deploy worker-workflows --type json -p='[
	  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"2"},
	  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"2"}
	]'
	
	kubectl patch deployment worker-workflows --type json -p='[ {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"6Gi"}, {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"6Gi"} ]'
	```
</details>
<details>
<summary>Tue Dec 16, 2025</summary>
	- upgraded app to `2025.1211.1216-dbedb3bc`
	- upgraded installer to `2025.12.05`
	- Set the following values
	```
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
	      cpu: 2
	      memory: 6Gi
	    requests:
	      cpu: 2
	      memory: 6Gi
	
	zeus:
	  resources:
	    limits:
	      cpu: 1
	      memory: 4Gi
	    requests:
	      cpu: 1
	      memory: 4Gi
	```
</details>
<details>
<summary>Wed Dec 17, 2025</summary>
	- upgraded app to `2025.1216.1236-565dcccf`
</details>
See [https://useparagon.slack.com/archives/C0ABBPYLL9W/p1769171404406009?thread_ts=1769155642.688999&cid=C0ABBPYLL9W](https://useparagon.slack.com/archives/C0ABBPYLL9W/p1769171404406009?thread_ts=1769155642.688999&cid=C0ABBPYLL9W)
<details>
<summary>Thu Feb 19, 2025</summary>
	- applied following: 
		```
		kubectl patch hpa cerberus -p '{"spec":{"minReplicas":2, "maxReplicas": 10}}'
		kubectl patch deploy cerberus --type json -p='[
		  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"500m"}
		]'
		```
	- updated `values.yaml` with 
		```
		cerberus:
		  autoscaling:
		    minReplicas: 2
		    maxReplicas: 10
		  resources:
		    limits:
		      memory: 512Mi
		    requests:
		      cpu: 0.5
		      memory: 512Mi
		```
</details>