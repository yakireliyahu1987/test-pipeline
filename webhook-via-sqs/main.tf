variable "region" {
  description = "The AWS region to deploy the webhook solution on."
  type = "string"
}

variable "profile" {
  description = "The AWS profile to use"
  type = "string"
}

variable "bitbucket-hook-uuid" {
  description = "The Bitbucket Hook ID. Leave empty if choosing GitHub"
  type = "string"
}

variable "bitbucket-ip-range" {
  type = "list"

  default = [
    "34.198.32.85",
    "34.198.178.64",
    "34.198.203.127",
    "104.192.136.0/21",
    "2401:1d80:1010::/64",
    "2401:1d80:1003::/64",
  ]
}

provider "github" {}

data "github_ip_ranges" "github-ip-ranges" {}

variable "github-secret" {
  description = "The GitHub webhook secret. Leave empty if choosing Bitbucket."
  type = "string"
}

locals {
  git_ip_ranges = "${coalescelist(var.bitbucket-hook-uuid,data.github_ip_ranges.github-ip-ranges.hooks)}"
  stage_variable_name = "${var.bitbucket-hook-uuid != "" ? "HookID" : "GithubSecret"}"
  stage_variable_value = "${var.bitbucket-hook-uuid != "" ? var.bitbucket-hook-uuid : var.github-secret}"
}

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}

// =============================== SQS ================================
data "aws_caller_identity" "self" {}

resource "aws_sqs_queue" "jenkins-build" {
  name                       = "jenkins-build-trigger"
  visibility_timeout_seconds = 1800
  redrive_policy             = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.jenkins-build-dlq.arn}\",\"maxReceiveCount\":1}"
}

resource "aws_sqs_queue" "jenkins-build-dlq" {
  name                      = "jenkins-build-trigger-dlq"
  message_retention_seconds = "604800"                    //one week
}

// =============================== API Gateway Hook ================================
data "aws_iam_policy_document" "api-gw-assume-role-policy" {
  "statement" {
    sid = "1"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = ["apigateway.amazonaws.com"]
      type        = "Service"
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "allow-access-to-sqs-from-api-gw" {
  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "sqs:SendMessage",
    ]

    resources = [
      "${aws_sqs_queue.jenkins-build.arn}",
    ]
  }
}

data "aws_iam_policy_document" "limit-access-to-bitbucket" {
  "statement" {
    sid       = "DenyUnlessFromBitbucket"
    effect    = "Deny"
    actions   = ["execute-api:Invoke"]
    resources = ["arn:aws:execute-api:${var.region}:${data.aws_caller_identity.self.account_id}:*/*"]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "NotIpAddress"
      values   = ["${local.git_ip_ranges}"]
      variable = "aws:SourceIp"
    }
  }

  "statement" {
    sid       = "DefaultAllow"
    effect    = "Allow"
    actions   = ["execute-api:Invoke"]
    resources = ["arn:aws:execute-api:${var.region}:${data.aws_caller_identity.self.account_id}:*/*"]

    principals {
      identifiers = ["*"]
      type        = "*"
    }
  }
}

resource "aws_iam_role" "api-gw-send-webhook-to-sqs-exectuion-role" {
  assume_role_policy = "${data.aws_iam_policy_document.api-gw-assume-role-policy.json}"
  name               = "api-gw-send-webhook-to-sqs-exectuion-role"
}

resource "aws_iam_role_policy" "allow-sqs-access-to-api-gw" {
  policy = "${data.aws_iam_policy_document.allow-access-to-sqs-from-api-gw.json}"
  role   = "${aws_iam_role.api-gw-send-webhook-to-sqs-exectuion-role.name}"
}

resource "aws_iam_role" "api-gw-cloudwatch-logging-role" {
  name               = "api-gw-cloudwatch-logging"
  assume_role_policy = "${data.aws_iam_policy_document.api-gw-assume-role-policy.json}"
}

resource "aws_iam_role_policy_attachment" "api-gw-cloudwatch-logging-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role       = "${aws_iam_role.api-gw-cloudwatch-logging-role.name}"
}

resource "aws_api_gateway_account" "build-trigger-logging-setup" {
  cloudwatch_role_arn = "${aws_iam_role.api-gw-cloudwatch-logging-role.arn}"
}

resource "aws_api_gateway_rest_api" "build-trigger-rest-api" {
  name        = "build-trigger"
  description = "This is an API for transferring webhooks to SQS"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  policy = "${data.aws_iam_policy_document.limit-access-to-bitbucket.json}"
}

resource "aws_api_gateway_resource" "build-trigger-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  parent_id   = "${aws_api_gateway_rest_api.build-trigger-rest-api.root_resource_id}"
  path_part   = "build"
}

resource "aws_api_gateway_method" "build-trigger-method" {
  rest_api_id   = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id   = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = "${aws_api_gateway_authorizer.build-trigger-authorizer.id}"

  request_parameters {
    "method.request.header.X-Attempt-Number" = true
    "method.request.header.X-Event-Key"      = true
    "method.request.header.X-Hook-UUID"      = true
    "method.request.header.X-Request-UUID"   = true
    "method.request.header.X-Hub-Signature"  = true
  }
}

resource "aws_api_gateway_method_response" "build-trigger-method-response" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method = "${aws_api_gateway_method.build-trigger-method.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_deployment" "v1" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  stage_name  = "v1"

  variables {
    "${local.stage_variable_name}" = "${local.stage_variable_value}"
  }

  depends_on = ["aws_api_gateway_integration.build-trigger-integration-to-sqs"]
}

resource "aws_api_gateway_method_settings" "build-trigger-settings" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  stage_name  = "${aws_api_gateway_deployment.v1.stage_name}"
  method_path = "${aws_api_gateway_resource.build-trigger-resource.path_part}/${aws_api_gateway_method.build-trigger-method.http_method}"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    throttling_rate_limit  = "1"
    throttling_burst_limit = "2"
  }

  depends_on = ["aws_api_gateway_account.build-trigger-logging-setup"]
}

resource "aws_api_gateway_integration" "build-trigger-integration-to-sqs" {
  rest_api_id             = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id             = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method             = "${aws_api_gateway_method.build-trigger-method.http_method}"
  integration_http_method = "${aws_api_gateway_method.build-trigger-method.http_method}"
  type                    = "AWS"
  timeout_milliseconds    = 29000
  credentials             = "${aws_iam_role.api-gw-send-webhook-to-sqs-exectuion-role.arn}"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.jenkins-build.name}"

  request_parameters = {
    "integration.request.header.Content-Type"     = "'application/json'"
    "integration.request.querystring.Action"      = "'SendMessage'"
    "integration.request.querystring.MessageBody" = "method.request.body"
  }
}

resource "aws_api_gateway_integration_response" "res-200" {
  http_method = "${aws_api_gateway_method.build-trigger-method.http_method}"
  resource_id = "${aws_api_gateway_resource.build-trigger-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  status_code = "200"
  depends_on  = ["aws_api_gateway_integration.build-trigger-integration-to-sqs"]
}

// =============================== Authorizer ================================
resource "aws_api_gateway_authorizer" "build-trigger-authorizer" {
  name                             = "build-trigger-authorize"
  rest_api_id                      = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  authorizer_uri                   = "${aws_lambda_function.build-trigger-authorizer-lambda-function.invoke_arn}"
  authorizer_credentials           = "${aws_iam_role.build-trigger-authorizer-role.arn}"
  authorizer_result_ttl_in_seconds = "0"
  type                             = "REQUEST"
  identity_source                  = "method.request.header.X-Hook-UUID,stageVariables.HookID"
}

resource "aws_iam_role" "build-trigger-authorizer-role" {
  name = "build-trigger-authorizer-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": "1"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "build-trigger-authorizer-invoke-lambda-policy" {
  name = "build-trigger-authorizer-role-execute-lambda"
  role = "${aws_iam_role.build-trigger-authorizer-role.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.build-trigger-authorizer-lambda-function.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role" "build-trigger-authorizer-lambda-execution-role" {
  name = "build-trigger-authorizer-lambda-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "build-trigger-authorizer-lambda-execution-role-cloudwatch-logging" {
  name = "build-trigger-authorizer-lambda-execution-role-cloudwatch-logging"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
POLICY

  role = "${aws_iam_role.build-trigger-authorizer-lambda-execution-role.name}"
}

data "archive_file" "lambda-zip" {
  source_file = "authorizer.js"
  output_path = "./lambda-function.zip"
  type        = "zip"
}

resource "aws_lambda_function" "build-trigger-authorizer-lambda-function" {
  filename         = "${data.archive_file.lambda-zip.output_path}"
  source_code_hash = "${data.archive_file.lambda-zip.output_base64sha256}"
  function_name    = "bitbucket_hook_authorizer"
  role             = "${aws_iam_role.build-trigger-authorizer-lambda-execution-role.arn}"
  handler          = "authorizer.handler"
  runtime          = "nodejs8.10"
}

// =============================== CORS Setup ================================
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.build-trigger-authorizer-lambda-function.arn}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.self.account_id}:${aws_api_gateway_rest_api.build-trigger-rest-api.id}/*/${aws_api_gateway_method.build-trigger-method.http_method}${aws_api_gateway_resource.build-trigger-resource.path}"
}

resource "aws_api_gateway_method" "build-trigger-options-method" {
  rest_api_id   = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id   = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "build-trigger-options-method-reponse-200" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method = "${aws_api_gateway_method.build-trigger-options-method.http_method}"
  status_code = "200"

  response_models {
    "application/json" = "Empty"
  }

  response_parameters {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  depends_on = ["aws_api_gateway_method.build-trigger-options-method"]
}

resource "aws_api_gateway_integration" "build-trigger-options-method-integration" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method = "${aws_api_gateway_method.build-trigger-options-method.http_method}"
  type        = "MOCK"
  depends_on  = ["aws_api_gateway_method.build-trigger-options-method"]
}

resource "aws_api_gateway_integration_response" "build-trigger-options-method-integration-response" {
  rest_api_id = "${aws_api_gateway_rest_api.build-trigger-rest-api.id}"
  resource_id = "${aws_api_gateway_resource.build-trigger-resource.id}"
  http_method = "${aws_api_gateway_method.build-trigger-options-method.http_method}"
  status_code = "${aws_api_gateway_method_response.build-trigger-options-method-reponse-200.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = ["aws_api_gateway_method_response.build-trigger-options-method-reponse-200"]
}

//Bitbucket webhook url
output "build_trigger_url" {
  value = "${aws_api_gateway_deployment.v1.invoke_url}${aws_api_gateway_resource.build-trigger-resource.path}"
}

//Update in Jenkins SQS plugin
output "sqs_queue_url" {
  value = "${aws_sqs_queue.jenkins-build.id}"
}
