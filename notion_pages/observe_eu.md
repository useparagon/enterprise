<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.integrations-eu.observe.ai/](https://dashboard.integrations-eu.observe.ai/)</td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.integrations-eu.observe.ai/](https://grafana.integrations.observe.ai/)</td>
	</tr>
</table>
We have bastion access - link is in one password.
### Deployment Notes
- They are completely unmanaged - Kishan Baranwal performed the initial install over Zoom.
- They use S3 for Terraform state instead of Terraform Cloud.
### Deployment Changelog
<details>
<summary>Mon May 12, 2025</summary>
	- initial deployment with app `2025.0509.1419-edb6238c` and installer `2025.5.9`
	- set flipt to local storage 
		```
		kubectl set env deploy/flipt FLIPT_STORAGE_TYPE=local
		kubectl set env deploy/flipt FLIPT_STORAGE_LOCAL_PATH=/etc/flipt
		```
</details>
<details>
<summary>Mon Aug 4, 2025</summary>
	- Patched openobserve memory limit
		```
		kubectl patch statefulset openobserve --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"4Gi"}]'
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
<summary>Nov 25, 2025</summary>
	- applied new `prometheus` patches
		```
		    Limits:
		      memory:  2Gi
		    Requests:
		      cpu:      500m
		      memory:   2Gi
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
<summary>Wed Dec 10, 2025</summary>
	- upgraded installer to `2025.12.05`
	- upgraded EKS to `1.32` with increased spot instance list
	- upgraded app to `2025.1209.1538-167d0fdb`
	- recreated all `main.tf`, `vars.auto.tfvars` and `values.yaml` files since they had lost them
</details>
<details>
<summary>Mon Mar 16, 2026</summary>
	- Upgraded installer to `2026.03.05`
	- Upgraded EKS to `1.33`
	- Upgraded app to `2026.0313.0323-949211c3`
	- Hoop.dev agent installed
</details>