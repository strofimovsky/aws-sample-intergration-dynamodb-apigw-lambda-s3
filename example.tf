variable "region" {
    default = "us-west-2"
}
    
provider "aws" {
  region = "${var.region}"
  profile                  = "default"
}

#
# IAM role
#

resource "aws_iam_role" "iam_for_lambda" {
    name = "iam_for_example_lambda"
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

resource "aws_iam_policy_attachment" "attach-lambda-policy" {
    name = "lambda-policy"
    roles = ["${aws_iam_role.iam_for_lambda.name}"]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy_attachment" "attach-ddb-policy" {
    name = "ddb-policy"
    roles = ["${aws_iam_role.iam_for_lambda.name}"]
    policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

#
# Lambda functions
#

resource "aws_lambda_function" "apicall_lambda" {
    filename = "apicall.zip"
    function_name = "apicall"
    role = "${aws_iam_role.iam_for_lambda.arn}"
    handler = "apicall.lambda_handler"
    source_code_hash = "${base64sha256(file("apicall.zip"))}"
    timeout = 60
    runtime = "python2.7"
}

resource "aws_lambda_function" "dataimport_lambda" {
    filename = "dataimport.zip"
    function_name = "dataimport"
    role = "${aws_iam_role.iam_for_lambda.arn}"
    handler = "dataimport.lambda_handler"
    source_code_hash = "${base64sha256(file("dataimport.zip"))}"
    timeout = 300
    runtime = "python2.7"
}

resource "aws_cloudwatch_event_rule" "daily-run" {
  name = "dataimport-daily-run"
  description = "Execute data imports daily"
  schedule_expression = "cron(30 1 ? * * *)"
}

resource "aws_cloudwatch_event_target" "daily-target" {
  target_id = "dataimport"
  rule = "${aws_cloudwatch_event_rule.daily-run.name}"
  arn = "${aws_lambda_function.dataimport_lambda.arn}"
}

resource "aws_lambda_permission" "allow_lambda" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.dataimport_lambda.arn}"
    principal = "events.amazonaws.com"
}

#
# API gateway
#

resource "aws_api_gateway_rest_api" "AWSExampleAPI" {
  name = "AWSExampleAPI"
  description = "This is a demo API"
}

resource "aws_api_gateway_resource" "date-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  parent_id = "${aws_api_gateway_rest_api.AWSExampleAPI.root_resource_id}"
  path_part = "date"
}

resource "aws_api_gateway_resource" "date-val-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  parent_id = "${aws_api_gateway_resource.date-resource.id}"
  path_part = "{val}"
}

resource "aws_api_gateway_method" "date-get" {
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  resource_id = "${aws_api_gateway_resource.date-val-resource.id}"
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "AWSExampleIntegration" {
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  resource_id = "${aws_api_gateway_resource.date-val-resource.id}"
  http_method = "${aws_api_gateway_method.date-get.http_method}"
  type = "AWS"
  integration_http_method = "POST"
#  credentials = "${aws_iam_role.iam_for_lambda.arn}"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.apicall_lambda.arn}/invocations"
  request_templates = {
     "application/json" = "${file("api_gateway_body_mapping.template")}"
  }
}

resource "aws_api_gateway_method_response" "200" {
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  resource_id = "${aws_api_gateway_resource.date-val-resource.id}"
  http_method = "${aws_api_gateway_method.date-get.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "AWSExampleIntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.AWSExampleIntegration"]
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  resource_id = "${aws_api_gateway_resource.date-val-resource.id}"
  http_method = "${aws_api_gateway_method.date-get.http_method}"
  status_code = "${aws_api_gateway_method_response.200.status_code}"
}

resource "aws_api_gateway_deployment" "AWSExampleDeployment" {
  depends_on = ["aws_api_gateway_integration.AWSExampleIntegration"]
  rest_api_id = "${aws_api_gateway_rest_api.AWSExampleAPI.id}"
  stage_name = "prod1"
}

#
# S3 web bucket
#

resource "aws_s3_bucket" "web" {
    bucket = "s3-website-test.example.com"
    acl = "public-read"
    force_destroy = true
    policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[{
    "Sid":"PublicReadGetObject",
        "Effect":"Allow",
      "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::s3-website-test.example.com/*"
      ]
    }
  ]
}
EOF
    website {
        index_document = "index.html"
        error_document = "error.html"
    }
}

resource "aws_s3_bucket_object" "index" {
    depends_on = ["aws_s3_bucket.web"]
    bucket = "s3-website-test.example.com"
    key = "index.html"
    source = "index.html"
    content_type = "text/html"
    etag = "${md5(file("index.html"))}"
}


#
# DynamoDB table
#
resource "aws_dynamodb_table" "dynamodb-table" {
    name = "FREDdata"
    read_capacity = 5
    write_capacity = 5
    hash_key = "date"
    range_key = "DCOILWTICO"
    attribute {
      name = "date"
      type = "S"
    }
    attribute {
      name = "DCOILWTICO"
      type = "S"
    }
}

# output

output "website" {
    value = "Website: ${aws_s3_bucket.web.website_endpoint}"
}

output "endpoint" {
    value = "API endpoint: https://${aws_api_gateway_rest_api.AWSExampleAPI.id}.execute-api.${var.region}.amazonaws.com/prod1"
}

