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

The pipeline supports secure Bitbucket webhook triggers on AWS using the following architecture:

    Bitbucket -> AWS API Gateway -> AWS Lambda -> AWS SQS -> Jenkins

This architecture is safer than exposing the Jenkins machine directly to the internet and can
provide a solution in cases where a standard webhook is out of the question due to security
constraints.

This architecture uses the [AWS SQS Plugin][8].

### Deploying the Webhook Solution

To configure a webhook on an existing Bitbucket repository, perform the following steps.

#### Set the Shell Variables

Set the following shell variables with the appropriate values:

```bash
bitbucket_user='<username>'
bitbucket_pass='<password>'
# Bitbucket organization / username under which the relevant repository exists.
bitbucket_org=<bitbucket_organization>
bitbucket_repo=<bitbucket_repository>
# AWS CLI profile to use. Make sure the profile is wired to the correct AWS account.
aws_profile=<profile_name>
# AWS region in which to deploy the AWS resources for the hook solution.
aws_region=<region>
```

#### Create the Webhook

Now, run the following command to create a hook:

```bash
hook_uuid=$(curl -s -X POST -u $bitbucket_user:$bitbucket_pass \
    -H 'Content-Type: application/json' \
    -d '{
      "description": "Terraform CD pipeline",
      "url": "https://example.com/",
      "active": false,
      "events": [
        "repo:push"
      ]
    }' https://api.bitbucket.org/2.0/repositories/$bitbucket_org/$bitbucket_repo/hooks \
    | jq -r '.uuid' | tr -d '{}')
```

For now, the hook will point at a dummy location. You will update the hook after creating the
resources on AWS.

#### Create the AWS Resources

Next, from a machine with AWS CLI configured for the correct AWS account, run the following command
under the `webhook-via-sqs` directory to create the necessary AWS resources:

```bash
cd webhook-via-sqs
terraform init
terraform apply -var profile=$aws_profile -var region=$aws_region -var bitbucket-hook-uuid=$hook_uuid
# Review the output, type 'yes' and hit enter.

# Remember the build trigger URL to update the hook.
build_trigger_url=$(terraform output build_trigger_url)
```

>NOTE: You may specify an AWS CLI profile by passing `-var profile=<profile_name>` to the
>`terraform apply` command.

#### Update the Webhook

Once the Terraform operation has finished, run the following in order to update the webhook to
point AWS API Gateway:

```bash
curl -s -X PUT -u $bitbucket_user:$bitbucket_pass \
    -H 'Content-Type: application/json' \
    -d '{
      "description": "Terraform CD pipeline",
      "url": "'$build_trigger_url'",
      "active": true,
      "events": [
        "repo:push"
      ]
    }' https://api.bitbucket.org/2.0/repositories/$bitbucket_org/$bitbucket_repo/hooks/$hook_uuid
```

#### Configure Jenkins

**TODO - do this automatically?**

Update the Jenkins AWS SQS Plugin to point at the created SQS queue:

  - Manage Jenkins -> Configure System -> Configuration of Amazon SQS queues.
  - Update "Queue name or URL" with the output of `terraform output sqs_queue_url`.
  - Save.

>NOTE: the plugin will fail to validate access to the queue if an IAM role is used for AWS
>authentication, however this can be safely ignored. The plugin will manage to access the queue,
>assuming the role's IAM policy permits it.

#### Update the Jenkins Job

**TODO - do this automatically?**

Finally, update the job to trigger a build using SQS:

- Configure -> Build Triggers -> Trigger build when a message is published to an Amazon SQS queue.
- Select from the dropdown list the queue you configured.
- Disable "Poll SCM" if enabled.
- Save the job.

In order to verify that the pipeline works as expected, push a change to the repository.

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
