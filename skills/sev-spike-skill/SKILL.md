---
name: sev-spike-skill
description: Skill for creating investigative spike tickets in Jira for SEV incidents
---

## What the sev-spike-skill does

This skill automates the creation of investigative spike tickets in the PARA Jira project for SEV incidents. Each SEV should get a corresponding spike ticket that tracks the RCA (Root Cause Analysis) investigation.

## When to use this skill

Use this skill when:
- A user asks to create a spike ticket for a SEV incident
- A user asks to investigate a SEV or create an RCA ticket
- A user references a `SEV-###` ticket and needs an investigative spike created

## Prerequisites

- Access to the `useparagon.atlassian.net` Jira instance via MCP/Atlassian tools
- The SEV ticket must already exist in the `SEV` (Incidents) project

## How to create a spike for a given SEV

Follow these steps exactly. All Jira API calls use `cloudId: f25fd3e2-c93b-4c7f-bcea-d3027d2fa860`.

### Step 1: Fetch the SEV incident

Retrieve the SEV ticket to extract its summary for the spike title.

```
Tool: getJiraIssue
  cloudId: f25fd3e2-c93b-4c7f-bcea-d3027d2fa860
  issueIdOrKey: SEV-{number}
```

From the response, note:
- `fields.summary` — used to build the spike summary
- `key` — used for linking

### Step 2: Determine the spike summary

The spike summary follows this pattern:

```
[SEV-{number}] Investigate {SEV summary}
```

For example, if `SEV-714` has summary `Enterprise Pipedrive US - Microservice hermes and 5 similar incidents`, the spike summary is:

```
[SEV-714] Investigate Enterprise Pipedrive US microservice hermes outages
```

Simplify the SEV summary into a concise description of the incident. Drop boilerplate like "and N similar incidents".

### Step 3: Create the spike ticket

Create the spike in the `PARA` project with issue type `Spike` (ID `10095`).

```
Tool: createJiraIssue
  cloudId: f25fd3e2-c93b-4c7f-bcea-d3027d2fa860
  projectKey: PARA
  issueTypeName: Spike
  summary: [SEV-{number}] Investigate {simplified description}
  description: See parent SEV for related incidents.
  contentFormat: markdown
  assignee_account_id: {current user's account ID, or the SEV assignee}
```

See [Spike Field Reference](references/spike-fields.md) for all required and optional fields.

### Step 4: Set the Team field

The Team field (`customfield_10001`) cannot be set during creation. Update it after:

```
Tool: editJiraIssue
  cloudId: f25fd3e2-c93b-4c7f-bcea-d3027d2fa860
  issueIdOrKey: {new PARA key}
  fields: { "customfield_10001": "32215538-d2c6-45df-972e-576c1f8a96ed" }
```

### Step 5: Link the spike to the SEV

Create a "Blocks" link where the spike blocks the SEV incident (the SEV is blocked by the spike completing its investigation).

```
Tool: createIssueLink
  cloudId: f25fd3e2-c93b-4c7f-bcea-d3027d2fa860
  inwardIssue: {new PARA key}    (the spike)
  outwardIssue: SEV-{number}     (the incident)
  type: Blocks
```

### Step 6: Verify

Fetch the newly created spike to confirm all fields and links are set correctly:

```
Tool: getJiraIssue
  cloudId: f25fd3e2-c93b-4c7f-bcea-d3027d2fa860
  issueIdOrKey: {new PARA key}
```

Confirm:
- [ ] Summary matches `[SEV-{number}] Investigate ...`
- [ ] Issue type is `Spike`
- [ ] Priority is `P1`
- [ ] Assignee is set
- [ ] Team is `Eng Team: Platform Engineering`
- [ ] Issue link to `SEV-{number}` exists with type `Blocks`
- [ ] Background/Technical Notes links to the SEV
- [ ] Investigation Questions are populated
- [ ] Definition of Done is populated

## Field Reference

See [Spike Field Reference](references/spike-fields.md) for the complete field mapping.
