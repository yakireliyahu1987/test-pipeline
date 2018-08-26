# Terraform Pipelines

**WORK IN PROGRESS - DO NOT USE!**

This is a reference for automated Terraform pipelines using Jenkins.

For the time being this repository includes a single pipeline. More pipelines might be added in the
future.

## Requirements

### Plugins

The pipeline requires a Jenkins server with the following plugins installed:

- [Pipeline][1]
- [Git Plugin][2]
- [AnsiColor Plugin][3]
- [Workspace Cleanup Plugin][4]
- [Email-ext plugin][7]
- [AWS SQS Plugin][8]
- [Pipeline Utility Steps][9]

### Build Executors

The pipeline relies on multiple downstream jobs which may run in parallel. To support this, Jenkins
must have enough **Build Executors** enabled.

### Terraform

In addition, the pipeline relies on a [Terraform][5] binary to be present at
`/usr/local/bin/terraform` (this path can be changed by editing a variable in the Jenkinsfile).

## Webhook Support
  + [Bitbucket Webhook Setup](webhook-via-sqs/bitbucket-webhook.md)
  + [GitHub Webhook Setup](webhook-via-sqs/github-webhook.md)
## TODO

- Backend configuration for development
  - [Separate][6] the backend config into a separate file and not load it when developing?
- Automated plan on feature branch creation?
- Notify a committer about a pending approval (with the plan output)
  - Currently there is a bug which causes missed emails in concurrent builds.
- Safety-related improvements and bug fixes
- Only apply on `master` branch

[1]: https://plugins.jenkins.io/workflow-aggregator
[2]: https://plugins.jenkins.io/git
[3]: https://plugins.jenkins.io/ansicolor
[4]: https://plugins.jenkins.io/ws-cleanup
[5]: https://www.terraform.io/downloads.html
[6]: https://www.terraform.io/docs/backends/config.html#partial-configuration
[7]: https://plugins.jenkins.io/email-ext
[8]: https://plugins.jenkins.io/aws-sqs
[9]: https://plugins.jenkins.io/pipeline-utility-steps
