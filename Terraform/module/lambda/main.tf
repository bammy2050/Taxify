data "aws_caller_identity" "current" {}


locals {
  #prefix              = var.prefix
  account_id           = data.aws_caller_identity.current.account_id
  ecr_repository_name  = "${var.prefix}-lambda-container"
  ecr_image_tag        = "${var.prefix}-image"
  timeout              = var.timeout
  package_type         = "Image"
  architectures        = ["x86_64"]
  statement_id         = "AllowExecutionFromCloudWatch"
  action               = "lambda:InvokeFunction"
  principal            = "events.amazonaws.com"
  cloudwatch_rule_name = "${var.prefix}-cloudwatch-rule"
  schedule_expression  = var.cron_schedule
}

resource "aws_ecr_repository" "repo" {
  name         = local.ecr_repository_name
  force_delete = true
}

resource "null_resource" "ecr_image" {
  triggers = {
    python_file = md5(file(var.python_file_path))
    docker_file = md5(file(var.docker_file_path))
  }

  provisioner "local-exec" {
    command = <<EOF
           aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.region}.amazonaws.com
           cd ${var.docker_build_path}
           cp ${var.helper_file_dir} .
           cp ${var.sql_file_dir} .
           docker buildx build --platform linux/arm64 -t ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag} .
           docker push ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag}
           rm helper.py
       EOF
  }
}

data "aws_ecr_image" "lambda_image" {
  depends_on = [
    null_resource.ecr_image
  ]
  repository_name = local.ecr_repository_name
  image_tag       = local.ecr_image_tag
}

data "aws_iam_role" "lambda-role" {
  name = var.iam_role_name
}

#*********LAMBDA FUNCTION***********#
resource "aws_lambda_function" "lambda_function" {
  depends_on = [
    null_resource.ecr_image
  ]
  function_name = "${var.prefix}-lambda"
  role          = data.aws_iam_role.lambda-role.arn
  timeout       = local.timeout
  image_uri     = "${aws_ecr_repository.repo.repository_url}@${data.aws_ecr_image.lambda_image.id}"
  package_type  = local.package_type
  architectures = local.architectures
  memory_size   = var.memory
  environment {
    variables = {
      SNOWFLAKE_USER      = "AWSLAMBDA"
    }
  }
  ephemeral_storage {
    size = var.ephemeral_storage # Min 512 MB and the Max 10240 MB
  }
}

output "lambda_name" {
  value = aws_lambda_function.lambda_function.id
}

#*********EVENT BRIDGE***********#
resource "aws_cloudwatch_event_rule" "lambda_event_rule" {
  name                = local.cloudwatch_rule_name
  description         = "retry scheduled every day at 2am"
  schedule_expression = var.cron_schedule
  #"rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  arn  = aws_lambda_function.lambda_function.arn
  rule = aws_cloudwatch_event_rule.lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rw_fallout_retry_step_deletion_lambda" {
  statement_id  = local.statement_id
  action        = local.action
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = local.principal
  source_arn    = aws_cloudwatch_event_rule.lambda_event_rule.arn
}