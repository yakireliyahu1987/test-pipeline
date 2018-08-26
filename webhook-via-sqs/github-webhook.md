# Github Webhook Setup

The pipeline supports secure GitHub webhook triggers on AWS using the following architecture:

    GitHub -> AWS API Gateway -> AWS Lambda -> AWS SQS -> Jenkins

This architecture is safer than exposing the Jenkins machine directly to the internet and can
provide a solution in cases where a standard webhook is out of the question due to security
constraints.

This architecture uses the [AWS SQS Plugin][8].

### Deploying the Webhook Solution

To configure a webhook on an existing GitHub repository, perform the following steps.

#### Set the Shell Variables

Set the following shell variables with the appropriate values:

```bash
github_user='<username>'
github_password='<password>'
# Github organization / username under which the relevant repository exists.
github_org='<github_organization>'
github_repo='<github_repository>'
# Generate a secret token - https://passwordsgenerator.net/
github_secret='<github_secret>'
# AWS CLI profile to use. Make sure the profile is wired to the correct AWS account.
aws_profile=<profile_name>
# AWS region in which to deploy the AWS resources for the hook solution.
aws_region=<region>
```

#### Create the AWS Resources

From a machine with AWS CLI configured for the correct AWS account, run the following command
under the `webhook-via-sqs` directory to create the necessary AWS resources:

```bash
cd webhook-via-sqs
terraform init
terraform apply -var profile=$aws_profile -var region=$aws_region -var github-secret=$github_secret
# Review the output, type 'yes' and hit enter.

# Remember the build trigger URL to update the hook.
build_trigger_url=$(terraform output build_trigger_url)
```

>NOTE: You may specify an AWS CLI profile by passing `-var profile=<profile_name>` to the
>`terraform apply` command.

#### Create the Webhook

Now, we'll create the webhook in GitHub using terraform's output of `build_trigger_url`
The following command will create the hook. It will prompt for GitHub OTP code. If the user is not configured with MFA access, leave it empty.

```bash
curl -XPOST -H "Accept: application/vnd.github.v3+json" -H "Content-Type: application/json" -H "X-GitHub-OTP: $(read -p "Enter OTP: " OTP; echo $OTP)" -u $github_user:$github_password \
https://api.github.com/repos/$github_team/$github_repo/hooks -d '{
  "name": "web",
  "active": true,
  "events": [
    "push"
  ],
  "config": {
    "url": "'$build_trigger_url'",
    "content_type": "json",
    "secret": "'$github_secret'"
  }
}'
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