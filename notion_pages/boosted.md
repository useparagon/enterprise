<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.integrations.boosted.ai/](https://dashboard.integrations.boosted.ai/)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.integrations.boosted.ai/](https://grafana.integrations.boosted.ai/)  (shared creds in 1Password)</td>
	</tr>
</table>
### Deployment Change Log
<details>
<summary>Mon Mar 3, 2025</summary>
	- initial installation with v2025.0227.0042-c96e2d52
	- added following to `values.yaml` 
		```
		worker-workflows:
		  env:
		    WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT: 0
		    WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT: 1
		```
</details>
<details>
<summary>Tue Mar 11, 2025</summary>
	- moved `values.yaml` because issue [https://useparagon.atlassian.net/browse/PARA-13216](https://useparagon.atlassian.net/browse/PARA-13216) 
		```
		global:
		  env:
		    NOTIFIER_STRATEGY: REDIS_PUB_SUB
		    WORKER_WORKFLOWS_MINIMUM_HERMES_PROCESSOR_QUEUE_COUNT: 0
		    WORKER_WORKFLOWS_MINIMUM_TEST_WORKFLOW_QUEUE_COUNT: 1
		```
</details>
<details>
<summary>Wed Apr 9, 2025</summary>
	- decreased spot usage and increased node size 
		```
		eks_spot_instance_percent       = 50
		eks_ondemand_node_instance_type = "t3a.xlarge,t3.xlarge"
		eks_spot_node_instance_type     = "t3a.xlarge,t3.xlarge"
		```
</details>
<details>
<summary>Thu Apr 24, 2025</summary>
	- upgraded app to `2025.0422.1636-717cb43e`
	- upgraded installer to `2025.4.23`
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
<summary>Tue Jun 10, 2025</summary>
	- upgraded app to `2025.0609.0956-a07d1f16`
	- upgraded installer to `2025.6.4`
	- update SMTP SES credentials [https://useparagon.slack.com/archives/C085J9GQB0B/p1749502514419329](https://useparagon.slack.com/archives/C085J9GQB0B/p1749502514419329) 
</details>
<details>
<summary>Wed Jul 23, 2025</summary>
	-  OOM incident [https://useparagon.slack.com/archives/C061U1ZPXNG/p1753309830883669](https://useparagon.slack.com/archives/C061U1ZPXNG/p1753309830883669) 
		```
		kubectl set env deploy/worker-workflows WORKER_WORKFLOWS_PARALLEL_PROCESSING_COUNT=1
		kubectl patch deploy worker-workflows --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"1.5"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"1.5"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"4Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"4Gi"}]'
		```
</details>
<details>
<summary>Tue Sep16, 2025</summary>
	- upgraded EKS to `1.32` with increased spot instances
	- upgraded app to `2025.0915.0715-adf49f6f`
	- upgraded installer to `2025.9.8`
	- update SMTP SES credentials [https://useparagon.slack.com/archives/C085J9GQB0B/p1749502514419329](https://useparagon.slack.com/archives/C085J9GQB0B/p1749502514419329) 
</details>
<details>
<summary>Fri Oct 3, 2025</summary>
	```
	kubectl patch deploy worker-workflows --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"2"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"2"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"8Gi"},{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"8Gi"}]'
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
<summary>Fri Dec 19, 2025</summary>
	  `SMTP_USERNAME` and `SMTP_PASSWORD` values rotated.<br><br>[https://useparagon.atlassian.net/browse/SUP-1152](https://useparagon.atlassian.net/browse/SUP-1152)  
</details>
<details>
<summary>Wed Jan 14, 2026</summary>
	- upgraded app to `2026.0107.1419-7fdb2b73`
	- upgraded installer to `2025.12.16`
	- added following to `values.yaml` 
	```yaml
	global:
	  env:
	    SMTP_USERNAME: <value_updated>
	    SMTP_PASSWORD: <value_updated>
	
	subchart:
	  cache-replay:
	    enabled: false
	  kafka-exporter:
	    enabled: false
	  health-checker:
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
	```yaml
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
	      memory: 8Gi
	    requests:
	      cpu: 2
	      memory: 8Gi
	```
</details>
<details>
<summary>Tue Mar 10, 2026</summary>
	- upgraded app to `2026.0309.1456-17d3e97d`
	- upgraded installer to `2026.03.05`
	- Upgraded EKS to `v1.33`
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>