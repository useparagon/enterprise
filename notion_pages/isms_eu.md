<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.integration.r4.isms.online](https://dashboard.integration.r4.isms.online)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.integration.r4.isms.online](https://grafana.integration.r4.isms.online) (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Change Log
<details>
<summary>Thu Dec 5, 2024</summary>
	- initial deployment of app v2024.1203.1503-5c5557b9
	- installer version v2.7.0
</details>
<details>
<summary>Wed Dec 11, 2024</summary>
	- added `AdminAccessRole` to aws-auth and KMS admins
</details>
<details>
<summary>Tue Mar 4, 2025</summary>
	- upgraded app to `2025.0227.0042-c96e2d52`
	- added following to `values.yaml` 
		```
		# renamed smtp vars
		    EMAIL_DELIVERY_SERVICE: sendgrid_local_templates
		    EMAIL_FROM_ADDRESS: not-a-real@email.com
		    
		# added flipt vars
		    FLIPT_STORAGE_GIT_AUTHENTICATION_BASIC_USERNAME: <redacted>
		    FLIPT_STORAGE_GIT_AUTHENTICATION_BASIC_PASSWORD: <redacted>
		
		# added
		worker-workflows:
		  env:
		    WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT: 0
		    WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT: 1
		```
</details>
<details>
<summary>Wed Apr 23, 2025</summary>
	- upgraded app to `2025.0422.1636-717cb43e`
	- upgraded installer to `2.11.0`
	- made following changes to `values.yaml`
		```
		    EMAIL_DELIVERY_SERVICE: none
		```
</details>
<details>
<summary>Thu May 1,2025</summary>
	- enabled feature flags manually with env variables
	```
	for s in account cerberus connect dashboard hades hermes passport pheme plato release worker-actions worker-actionkit worker-credentials worker-crons worker-deployments worker-proxy worker-triggers worker-workflows zeus; do kubectl set env deployment/$s FEATURE_FLAG_PLATFORM_ENABLED=true FEATURE_FLAG_PLAFORM_ENABLED=true
	done > /dev/null 2> /dev/null
	```
</details>
<details>
<summary>Sat May 10. 2025</summary>
	- fixed zeus HPA 
		```
		kubectl patch hpa zeus -p '{"spec":{"minReplicas": 2, "maxReplicas": 6}}'
		kubectl patch deploy zeus --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"500m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"500m"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"1.5Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"1.5Gi"}]'
		```
</details>
<details>
<summary>Thu May 22, 2025</summary>
	- upgraded app to `2025.0521.1424-fad5a732`
	- upgraded installer to `2.12.0`
	- added following to `values.yaml` 
		```
		zeus:
		  resources:
		    limits:
		      cpu: 0.5
		      memory: 1.5Gi
		    requests:
		      cpu: 0.5
		      memory: 1.5Gi
		```
</details>
<details>
<summary>Thu Jun 26, 2025</summary>
	- upgraded app to `2025.0624.2344-ec77ad33`
	- upgraded installer to `2.13.0`
</details>
<details>
<summary>Thu Jul 17, 2025</summary>
	- upgraded app to `2025.0715.0855-f1f9fa5d`
</details>
<details>
<summary>Wed Jul 23, 2025</summary>
	- upgraded app to `2025.0723.0705-7afe58cf`
</details>
<details>
<summary>Thu Aug 21, 2025</summary>
	- upgraded app to `2025.0820.0949-7c4a47c2`
</details>
<details>
<summary>Thu Sep 18, 2025</summary>
	- upgraded EKS to `1.32` with expanded spot instance list
	- upgraded installer to `2.14.0`
	- upgraded app to `2025.0916.2327-c189514c`
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
<summary>Wed Nov 19, 2025</summary>
	- upgraded app to `2025.1113.1540-de37e7f4`
	- upgraded installer to `2.15.0`
	- Added the following values
	```yaml
	global:
	  env:
	    CLOUD_STORAGE_TYPE:                   S3
	    CLOUD_STORAGE_PUBLIC_URL:             https://s3.eu-central-1.amazonaws.com
	    CLOUD_STORAGE_PRIVATE_URL:            https://s3.eu-central-1.amazonaws.com
	    CLOUD_STORAGE_PUBLIC_BUCKET:          paragon-enterprise-isms-eu-cdn
	    CLOUD_STORAGE_SYSTEM_BUCKET:          paragon-enterprise-isms-eu
	    CLOUD_STORAGE_MICROSERVICE_PASS:      <redacted>
	    CLOUD_STORAGE_MICROSERVICE_USER:      <redacted>
	    CLOUD_STORAGE_REGION:                 eu-central-1
	
	    ZEUS_JWT_SECRET: <redacted>
	
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
	      cpu: 2
	      memory: 4Gi
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
<details>
<summary>Mon Feb 2, 2026</summary>
	- upgraded app to `2026.0129.1538-6594655b`
	- upgraded installer to `3.0.0`
	- Added the following values
	```yaml
	subchart:
	  cache-replay:
	    enabled: false
	  worker-auditlogs:
	    enabled: false
	```
</details>
<details>
<summary>Mon Mar 2, 2026</summary>
	- MIGRATED `aws-on-prem` TO `enterprise` REPO
	- upgraded installer to `2026.02.26`
	- upgraded Paragon to `2026.0226.1106-8d365a2f`
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>