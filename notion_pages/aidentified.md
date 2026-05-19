<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.aidentified.paragon.so/](https://dashboard.aidentified.paragon.so/infoz) </td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.aidentified.paragon.so](https://grafana.aidentified.paragon.so) (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Changelog
<details>
<summary>Thu Dec 7, 2023</summary>
	- initial deployment to AWS
	- installer version v2.2.0
	- app version v3.01.0
</details>
<details>
<summary>Mon Jul 29, 2024</summary>
	- upgraded installer to v2.4.0
	- upgraded app to v3.8.3
	- cleared old kibana indexes to free space
	- added following to `values.yaml` 
		```
		fluent-bit:
		  resources:
		    limits:
		      cpu: 100m
		      memory: 256Mi
		    request:
		      cpu: 50m
		      memory: 256Mi
		
		hades:
		  resources:
		    limits:
		      memory: 2Gi
		    requests:
		      memory: 2Gi
		```
</details>
<details>
<summary>Tue Nov 5, 2024</summary>
	- upgraded installer to v2.7.0
	- upgraded app to v2024.1105.0449-a3bc3353
	- upgraded EKS to 1.31
	- added following to `values.yaml` 
		```
		    MONITOR_PROMETHEUS_RETENTION_SIZE: 15GB
		    MONITOR_PROMETHEUS_RETENTION_TIME: 30d
		```
</details>
<details>
<summary>Wed Apr 9, 2025</summary>
	- hpa changes to minimize 503s 
		```
		kubectl patch hpa account -n paragon -p '{ "spec": { "minReplicas": 2,  "maxReplicas": 4, "metrics": [ { "type": "Resource", "resource": { "name": "cpu", "target": { "type": "Utilization", "averageUtilization": 70 } } }, { "type": "Resource", "resource": { "name": "memory", "target": { "type": "Utilization", "averageUtilization": 70 } } } ] } }'
		
		kubectl patch hpa cerberus -n paragon -p '{ "spec": { "minReplicas": 2,  "maxReplicas": 4 } }'
		
		kubectl patch hpa worker-actions -n paragon -p '{ "spec": { "minReplicas": 2 } }'
		kubectl patch hpa worker-workflows -n paragon -p '{ "spec": { "minReplicas": 4 } }'
		```
</details>
<details>
<summary>Wed May 28, 2025</summary>
	- upgraded app to `2025.0527.0604-412fe544`
	- upgraded installer to`2.12.0`
	- removed unnecessary `values.yaml` settings
	- added the following
		```
		    EMAIL_DELIVERY_SERVICE: sendgrid_local_templates
		    EMAIL_FROM_ADDRESS: integrations@aidentified.com
		    FLIPT_STORAGE_GIT_AUTHENTICATION_BASIC_USERNAME: paragonbot
		    FLIPT_STORAGE_GIT_AUTHENTICATION_BASIC_PASSWORD: <redacted>
		```
</details>
<details>
<summary>Mon Jul 28, 2025</summary>
	- upgraded app to `2025.0725.2015-fd3145f6`
	- upgraded installer to `2.13.0`
	- updated expired `SENDGRID_API_KEY`
</details>
<details>
<summary>Wed Sep 24, 2025</summary>
	- upgraded EKS to `1.32` with increased spot instance types
	- upgraded installer to `2.14.0`
	- upgraded app to `2025.0918.1305-9abd3cb0`
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
	- added following to `values.yaml` 
		```
		    AWS_REGION: us-west-2
		    CLOUD_STORAGE_MICROSERVICE_PASS: <redacted>
		    CLOUD_STORAGE_MICROSERVICE_USER: AKIAU6GDU3ITCAI6FMNF
		    CLOUD_STORAGE_TYPE: S3
		
		    ZEUS_JWT_SECRET: <redacted>
		
		minio:
		  autoscaling:
		    enabled: false
		  replicaCount: 0
		
		worker-workflows:
		  autoscaling:
		    enabled: false
		  replicaCount: 4
		  resources:
		    limits:
		      memory: 4Gi
		    requests:
		      cpu: 2
		      memory: 4Gi
		```
	- ran the following to fix `CLOUD_STORAGE_PRIVATE_URL` 
		```
		BASTION_REPO=aws-on-prem ./migrate-minio-to-s3.sh apply
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
<summary>Mon Dec 8, 2025</summary>
	- upgraded app to `2025.1203.0813-3d531142`
	- upgraded installer to`2.15.0`
	- Remove the following from `values.yaml` as they are no longer required
	```
	minio:
	  autoscaling:
	    enabled: false
	  replicaCount: 0
	
	zeus:
	  autoscaling:
	    targetCPUUtilizationPercentage: 70
	    targetMemoryUtilizationPercentage: 70
	```
</details>
<details>
<summary>Tue Feb, 24, 2026</summary>
	- MIGRATED `aws-on-prem` TO `enterprise` REPO
	- upgraded installer to `2026.02.17`
	- upgraded Paragon to `2026.0223.1500-dd2b0920`
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>