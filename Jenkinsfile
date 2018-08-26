// Relative path to the Terraform environment directory. This directory should contain the
// "root" module for every environment which this pipeline manages.
environment_dir = "./environments"
// Name of the downstream Jenkins job which runs Terraform for each environment.
downstream_job = "UpdateTerraformEnvironment"

properties([
    parameters([
        booleanParam(
            name: 'AlignAllEnvironments',
            description: 'Run on all existing environments to ensure they are up to date.',
            defaultValue: false
        ),
        // This parameter is populated by the AWS SQS Plugin (https://wiki.jenkins.io/display/JENKINS/AWS+SQS+Plugin).
        string(
            name: 'sqs_body',
            description: 'The body of the webhook which triggered the pipeline. Leave empty when triggering the build manually.',
            defaultValue: ''
        ),
    ])
])

node {
    checkout scm

    // Alignment requested by user - trigger downstream jobs for all existing environments without
    // checking for diffs.
    if (params.AlignAllEnvironments) {
        echo "Alignment job requested. Triggering downstream jobs for all environments."

        envs = []
        output = sh(
            script: "ls -d ${environment_dir}/*/ | cut -d '/' -f3",
            returnStdout: true
        ).trim()

        // Exit normally if output is empty.
        if (!output?.trim()) {
            error "No environments found."
        }

        // Append environment names to list.
        output.split('\n').each {
            envs << it
        }

        // Construct a map of downstream jobs for parallel execution.
        jobs = envs.collectEntries {
            [(it): constructJob(it)]
        }

        // Run jobs in parallel.
        echo "Triggering downstream jobs for all environments."
        parallel jobs
        return
    }

    echo "Checking for changes in all environments."
    def changeset = "HEAD^"
    if (params.sqs_body?.trim()) {
      def webhook_body = readJSON text: "${params.sqs_body}"
      def git_changes = webhook_body.push.changes[0]
      changeset = "${git_changes.old.target.hash}" + " " + "${git_changes.new.target.hash}"
    }
    // Get modified environments.
    modified_envs = []
    output = sh(
        script: "git diff --name-only ${changeset} -- ${environment_dir} | cut -d '/' -f2 | sort | uniq",
        returnStdout: true
    ).trim()

    // Exit normally if output is empty.
    if (!output?.trim()) {
        echo "No modified environments."
        currentBuild.result = 'SUCCESS'
        return
    }

    // Append environment names to list.
    output.split('\n').each {
        echo "Environment '${it}' has been modified."
        modified_envs << it
    }

    // Construct a map of downstream jobs for parallel execution.
    jobs = modified_envs.collectEntries {
        [(it): constructJob(it)]
    }

    // Run jobs in parallel.
    echo "Triggering downstream jobs for all modified environments."
    parallel jobs
}

def constructJob(name) {
    return {
        build(
            job: downstream_job,
            parameters: [
                [
                    $class: 'StringParameterValue',
                    name: 'EnvironmentName',
                    value: name
                ]
            ]
        )
    }
}
