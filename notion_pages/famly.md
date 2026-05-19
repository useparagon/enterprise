<table header-row="true">
	<tr>
		<td>**Service**</td>
		<td>**URL**</td>
	</tr>
	<tr>
		<td>Dashboard</td>
		<td>[https://dashboard.paragon.famly.co](https://dashboard.paragon.famly.co) </td>
	</tr>
	<tr>
		<td>Grafana</td>
		<td>[https://grafana.paragon.famly.co](https://grafana.paragon.famly.co) (requires them to invite you for access)</td>
	</tr>
</table>
Reach out to #paragon-famly to get access to Grafana.
### Deployment Changelog
<details>
<summary>Wed Jan 24, 2024</summary>
	- app version from v2.71.0 → v2.93.1
	- k8s version from 1.24 → 1.25
</details>
<details>
<summary>Mon Apr 15, 2024</summary>
	- app version from v2.93.1 → v3.00.1
</details>
<details>
<summary>Tue Jul 16, 2024</summary>
	- app version from v3.00.1 → v3.7.4
</details>
<details>
<summary>Wed Nov 6, 2024</summary>
	- upgraded installer to v2.7.0
	- upgraded app to v2024.1105.0449-a3bc3353
	- upgrading to EKS to 1.31 (Jakob handling async)
</details>
<details>
<summary>Fri Mar 28, 2025</summary>
	- [provided instructions](https://useparagon.slack.com/archives/C041EB56KNE/p1743185137572119?thread_ts=1741822164.960709&cid=C041EB56KNE) to:
		- upgrade installer to `2.9.0`
		- upgrade app to `2025.0328.0025-730d6baa`
		- update `values.yaml` and `features.yml`
</details>
<details>
<summary>Thu Aug 28, 2025</summary>
	- [provided instructions](https://useparagon.slack.com/archives/C041EB56KNE/p1756402974876499?thread_ts=1756300736.501249&cid=C041EB56KNE) to:
		- upgrade installer to `2.14.0`
		- upgrade app to `2025.0826.2228-74b5e79e`
		- update `.env-tf-infra` and `values.yaml`
</details>
<callout icon="⚠️" color="yellow_bg">
	Change the hoop.dev Slack channel to: `hoop_slack_channel_ids = ["C0AL05YQF3L"]`
</callout>