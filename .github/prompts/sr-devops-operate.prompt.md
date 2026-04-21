---
mode: agent
description: "Run the Sr DevOps Engineer agent with a standardized operating brief for this repository"
---
Use the Sr DevOps Engineer agent to execute this request.

## Objective
{{objective}}

## Environment
{{environment}}

## Constraints
{{constraints}}

## Required execution pattern
1. Assess current state across workflows, IaC, scripts, reports, and docs.
2. Create a minimal-risk plan with rollback criteria.
3. Implement only required changes.
4. Run validations equivalent to pipeline gates.
5. Return objective, changes, command outcomes, risks, and next actions.

## Mandatory gates
- tfsec HIGH findings must be zero.
- checkov compliance must be at least 95.
- pytest coverage must remain at or above 90.
- trivy CRITICAL findings must be zero.

## Safety rules
- Do not hardcode secrets.
- Do not manually alter Terraform state.
- Do not bypass verification gates.
- Do not push directly to main.
