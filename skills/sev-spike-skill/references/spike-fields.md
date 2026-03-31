# Spike Field Reference

This document lists every field that should be set when creating an investigative spike for a SEV incident.

## Jira Identifiers

| Identifier | Value |
|---|---|
| Cloud ID | `f25fd3e2-c93b-4c7f-bcea-d3027d2fa860` |
| Project Key | `PARA` |
| Issue Type Name | `Spike` |
| Issue Type ID | `10095` |

## Required Fields

These fields must be provided at creation time. The Jira API will reject the request if any are missing.

### Standard Fields

| Field | Value | Notes |
|---|---|---|
| `summary` | `[SEV-{number}] Investigate {description}` | Derive description from the SEV summary |
| `description` | `See parent SEV for related incidents.` | Matches existing convention |
| `issuetype` | `Spike` | Use `issueTypeName: "Spike"` |
| `priority` | `{ "id": "2" }` | P1 |

### Custom Fields (Required)

| Field ID | Field Name | Value | Notes |
|---|---|---|---|
| `customfield_10144` | Background / Technical Notes | ADF with inlineCard link to SEV | See ADF template below |

## Optional Fields (Recommended)

These fields match the conventions observed in existing spike tickets and should be populated.

### Custom Fields

| Field ID | Field Name | Value | Notes |
|---|---|---|---|
| `customfield_10026` | Story Points | `4` | Standard for SEV spikes |
| `customfield_10063` | Complexity | `{ "id": "10029" }` | `medium` |
| `customfield_10061` | (internal field) | `3` | Matches existing spikes |
| `customfield_10710` | Area | `{ "id": "10641" }` | `Infra - Kubernetes` |
| `customfield_10711` | Work Type | `{ "id": "10576" }` | `Defect / Tech Debt / Refactor` |
| `customfield_10712` | Purpose | `{ "id": "10580" }` | `02 - SEV Prevention` |
| `customfield_10643` | Size | `{ "id": "10448" }` | `S: A few hours` |
| `customfield_10145` | Investigation Questions | ADF ordered list | See ADF template below |
| `customfield_10146` | Definition of Done | ADF paragraph | See ADF template below |

### Post-Creation Fields

These fields cannot be set during issue creation and must be updated after.

| Field ID | Field Name | Value | Notes |
|---|---|---|---|
| `customfield_10001` | Team | `"32215538-d2c6-45df-972e-576c1f8a96ed"` | `Eng Team: Platform Engineering` |

### Fields NOT to set

| Field | Reason |
|---|---|
| `labels` | Sprint labels (e.g. `sprint:3.52:start`) are sprint-specific and should not be automated |

## ADF Templates

### Background / Technical Notes (`customfield_10144`)

Contains an inline card linking to the parent SEV ticket.

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "inlineCard",
          "attrs": {
            "url": "https://useparagon.atlassian.net/browse/SEV-{number}"
          }
        },
        { "type": "text", "text": " " }
      ]
    }
  ]
}
```

### Investigation Questions (`customfield_10145`)

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "orderedList",
      "attrs": { "order": 1 },
      "content": [
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "What caused the incident?" }]
            }
          ]
        },
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "How was it resolved?" }]
            }
          ]
        },
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "What was the customer impact?" }]
            }
          ]
        },
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "How can it be prevented in the future?" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

### Definition of Done (`customfield_10146`)

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Root cause identified and RCA completed." }
      ]
    }
  ]
}
```

## Issue Link

After creating the spike, link it to the SEV using the `Blocks` link type.

| Parameter | Value |
|---|---|
| `inwardIssue` | The new `PARA-{number}` spike key |
| `outwardIssue` | `SEV-{number}` |
| `type` | `Blocks` |

This creates the relationship: the spike **blocks** the SEV (i.e., the SEV is blocked by the spike until the investigation is complete).

## Area Field Alternatives

The Area field (`customfield_10710`) default is `Infra - Kubernetes` (ID `10641`). Other common values:

| Value | ID |
|---|---|
| `Infra - Kubernetes` | `10641` |
| `Infra - AWS` | `10608` |

Choose the value that best matches the SEV incident. If the SEV involves AWS-level issues (ALB, networking), use `Infra - AWS`. For service/pod restarts and Kubernetes-level issues, use `Infra - Kubernetes`.

## Assignee

The spike should be assigned to the same person who is assigned to the SEV incident. Use the `accountId` from the SEV's `fields.assignee` object.

If no assignee is set on the SEV, use the current authenticated user's account ID (retrievable via the `atlassianUserInfo` tool).

## Example: Full `additional_fields` for createJiraIssue

```json
{
  "priority": { "id": "2" },
  "customfield_10026": 4,
  "customfield_10063": { "id": "10029" },
  "customfield_10061": 3,
  "customfield_10710": { "id": "10641" },
  "customfield_10711": { "id": "10576" },
  "customfield_10712": { "id": "10580" },
  "customfield_10643": { "id": "10448" },
  "customfield_10144": { "...ADF for Background/Technical Notes..." },
  "customfield_10145": { "...ADF for Investigation Questions..." },
  "customfield_10146": { "...ADF for Definition of Done..." }
}
```
