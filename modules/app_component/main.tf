# ---------------------------------------------------------------------------------------------------------------------
# App Component (AWS)
# Features (pre-configured)
# - debug: ECS Connect
# - costs: scale down on non-working hours (can save costs for non-prod environments)
# - security: default read-only root filesystem for containers (complies with Basic Sec rules)
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# Service definition, auto heals if task shuts down
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_service" "ecs_service" {
  name             = "${var.name}Service"
  cluster          = data.aws_ecs_cluster.selected.arn
  task_definition  = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count    = var.instances
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # for ECS exec
  enable_execute_command = var.enable_ecs_exec

  network_configuration {
    subnets = data.aws_subnets.private_subnets.ids

    # if security groups are given, then overwrite default, otherwise take default (ecs_default + mysql_marker)
    security_groups = length(var.service_sg) == 0 ? [
      data.aws_security_group.ecs_default_sg.id, data.aws_security_group.mysql_marker_sg.id
    ] : var.service_sg
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = var.container[0].name
    container_port   = var.service_port
  }

  # Ignored desired count changes live, permitting schedulers to update this value without terraform reverting
  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Task definition
# Will be relaunched by service frequently
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = var.name
  execution_role_arn       = aws_iam_role.ExecutionRole.arn
  task_role_arn            = aws_iam_role.task.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  # Fargate cpu/mem must match available options: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
  cpu    = var.total_cpu
  memory = var.total_memory

  container_definitions = local.json_map

  tags = {
    Name = "${var.name}-task-def"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Link to loadbalancer: target group and lb listener
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_target_group" "target_group" {
  name_prefix          = substr(replace(var.name, "_", "-"), 0, 6)
  port                 = var.service_port
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.selected.id
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  health_check {
    healthy_threshold   = "3"
    port                = var.lb_healthcheck_port
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.lb_healthcheck_url
    unhealthy_threshold = "2"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# HTTPS (Port 443) listener + rules
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "port_443" {
  count = var.lb_domain_name == "" ? 0 : 1

  load_balancer_arn = data.aws_ssm_parameter.alb_arn.value
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.certificate[0].arn
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"

  # if no attached rule matches, do this
  default_action {
    type = "redirect"
    redirect {
      host        = var.default_redirect_url
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_302"
    }
  }
}

resource "aws_lb_listener_rule" "https_listener_rule" {
  count = var.lb_domain_name == "" ? 0 : 1

  listener_arn = aws_lb_listener.port_443[0].arn
  priority     = var.listener_rule_prio

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  # Exactly one of host_header, http_header, http_request_method, path_pattern, query_string or source_ip must be set per condition.
  # Multiple conditions declare an AND operation
  condition {
    path_pattern {
      values = [var.path_mapping]
    }
  }

  depends_on = [aws_lb_target_group.target_group]
}

# ---------------------------------------------------------------------------------------------------------------------
# attaches trailing slash in case it recognizes one
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "https_trailing_slash_redirect" {
  count = var.lb_domain_name == "" ? 0 : 1

  listener_arn = aws_lb_listener.port_443[0].arn
  priority     = var.listener_rule_prio + 1 # make rule appear after the default rule

  action {
    type = "redirect"
    redirect {
      host        = "#{host}"
      path        = "/#{path}/" # trailing slash is added here
      query       = "#{query}"
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  # Exactly one of host_header, http_header, http_request_method, path_pattern, query_string or source_ip must be set per condition.
  # Multiple conditions declare an AND operation
  condition {
    path_pattern {
      values = [(length(var.path_mapping) > 2) ? trimsuffix(var.path_mapping, "/*") : var.path_mapping]
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# HTTP (Port 80) listener + rules
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener" "port_80" {
  load_balancer_arn = data.aws_ssm_parameter.alb_arn.value
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      host        = "terra3.io"
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_302"
    }
  }
}

resource "aws_lb_listener_rule" "http_listener_rule" {
  listener_arn = aws_lb_listener.port_80.arn
  priority     = var.listener_rule_prio

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  # Exactly one of host_header, http_header, http_request_method, path_pattern, query_string or source_ip must be set per condition.
  # Multiple conditions declare an AND operation
  condition {
    path_pattern {
      values = [var.path_mapping]
    }
  }

  depends_on = [aws_lb_target_group.target_group]
}

# ---------------------------------------------------------------------------------------------------------------------
# attaches trailing slash in case it recognizes one
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "http_trailing_slash_redirect" {
  listener_arn = aws_lb_listener.port_80.arn
  priority     = var.listener_rule_prio + 1 # make rule appear after the default rule

  action {
    type = "redirect"
    redirect {
      host        = "#{host}"
      path        = "/#{path}/" # trailing slash is added here
      query       = "#{query}"
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  # Exactly one of host_header, http_header, http_request_method, path_pattern, query_string or source_ip must be set per condition.
  # Multiple conditions declare an AND operation
  condition {
    path_pattern {
      values = [(length(var.path_mapping) > 2) ? trimsuffix(var.path_mapping, "/*") : var.path_mapping]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Cloudwatch to store logs
# ---------------------------------------------------------------------------------------------------------------------
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "CloudWatchLogGroup" {
  name = "${var.name}LogGroup"

  retention_in_days = 7

  tags = {
    Name = "${var.name}LogGroup"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# Autoscaling logic for scaling up and down to save costs and for resets
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# Create autoscaling target linked to ECS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_appautoscaling_target" "ServiceAutoScalingTarget" {
  count              = var.enable_autoscaling ? 1 : 0
  min_capacity       = var.autoscale_task_weekday_scale_down
  max_capacity       = var.desired_count
  resource_id        = "service/${var.container_runtime}/${aws_ecs_service.ecs_service.name}" # service/(clusterName)/(serviceName)
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [
      min_capacity,
      max_capacity,
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Scale down on weekdays logic to save costs
# Scale up weekdays at beginning of day
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_appautoscaling_scheduled_action" "WeekdayScaleUp" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.name}ScaleUp"
  service_namespace  = aws_appautoscaling_target.ServiceAutoScalingTarget[0].service_namespace
  resource_id        = aws_appautoscaling_target.ServiceAutoScalingTarget[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ServiceAutoScalingTarget[0].scalable_dimension
  schedule           = var.autoscale_up_event
  timezone           = "Europe/Berlin"

  scalable_target_action {
    min_capacity = var.desired_count
    max_capacity = var.desired_count
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Scale down weekdays at end of day
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_appautoscaling_scheduled_action" "WeekdayScaleDown" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.name}ScaleDown"
  service_namespace  = aws_appautoscaling_target.ServiceAutoScalingTarget[0].service_namespace
  resource_id        = aws_appautoscaling_target.ServiceAutoScalingTarget[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ServiceAutoScalingTarget[0].scalable_dimension
  schedule           = var.autoscale_down_event
  timezone           = "Europe/Berlin"

  scalable_target_action {
    min_capacity = var.autoscale_task_weekday_scale_down
    max_capacity = var.autoscale_task_weekday_scale_down
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS Exec specific
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# IAM Role Definitions
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "ExecutionRole" {
  name = "${var.name}-ExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.name}ExecutionRole"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Link to AWS-managed policy - AmazonECSTaskExecutionRolePolicy
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ExecutionRole_to_ecsTaskExecutionRole" {
  role       = aws_iam_role.ExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------------------------------------------------
# Construct IAM policies
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Find all secret ARNs and output as a list
  execution_iam_secrets = try(
    flatten([
      for permission_type, permission_targets in var.execution_iam_access : [
        for secret in permission_targets : "${secret}*"
      ]
      if permission_type == "secrets"
    ]),
    # If nothing provided, default to empty set
    [],
  )

  # Final all S3 bucket ARNs and output as list
  execution_iam_s3_buckets = try(
    flatten([
      for permission_type, permission_targets in var.execution_iam_access : permission_targets if permission_type == "s3_buckets"
    ]),
    # If nothing provided, default to empty set
    [],
  )

  # Find all S3 bucket ARNs and output as list for object access
  execution_iam_s3_buckets_object_access = try(
    flatten(
      [
        for buckets in local.execution_iam_s3_buckets : "${buckets}/*"
      ]
    ),
    # If nothing provided, default to empty set
    [],
  )

  # Find all KMS CMK ARNs passed to module and output as a list
  execution_iam_kms_cmk = try(
    flatten([
      for permission_type, permission_targets in var.execution_iam_access : [
        for kms_cmk in permission_targets : kms_cmk
      ]
      if permission_type == "kms_cmk"
    ]),
    # If nothing provided, default to empty set
    [],
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Construct the secrets policy
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_secrets_access" {
  count = local.execution_iam_secrets == [] ? 0 : 1
  statement {
    sid = "EcsSecretAccess"
    #effect = "Allow"
    resources = local.execution_iam_secrets
    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt"
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Build role policy using data, link to role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecs_secrets_access_role_policy" {
  count  = local.execution_iam_secrets == [] ? 0 : 1
  name   = "EcsSecretExecutionRolePolicy"
  role   = aws_iam_role.ExecutionRole.id
  policy = data.aws_iam_policy_document.ecs_secrets_access[0].json
}

# ---------------------------------------------------------------------------------------------------------------------
# Construct the S3 bucket list policy
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_bucket_list_access" {
  count = local.execution_iam_s3_buckets == [] ? 0 : 1
  statement {
    sid       = "S3ListBucketAccess"
    effect    = "Allow"
    resources = local.execution_iam_s3_buckets
    actions = [
      "s3:ListBucket",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Build role policy using data, link to role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecs_s3_bucket_list_access_role_policy" {
  count  = local.execution_iam_s3_buckets == [] ? 0 : 1
  name   = "EcsS3BucketListExecutionRolePolicy"
  role   = aws_iam_role.ExecutionRole.id
  policy = data.aws_iam_policy_document.s3_bucket_list_access[0].json
}

# ---------------------------------------------------------------------------------------------------------------------
# Construct the S3 bucket object policy
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_bucket_object_access" {
  count = local.execution_iam_s3_buckets_object_access == [] ? 0 : 1
  statement {
    sid       = "S3BucketObjectAccess"
    effect    = "Allow"
    resources = local.execution_iam_s3_buckets_object_access
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Build role policy using data, link to role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecs_s3_bucket_object_access_role_policy" {
  count  = local.execution_iam_s3_buckets_object_access == [] ? 0 : 1
  name   = "EcsS3BucketObjectAccessExecutionRolePolicy"
  role   = aws_iam_role.ExecutionRole.id
  policy = data.aws_iam_policy_document.s3_bucket_object_access[0].json
}

# ---------------------------------------------------------------------------------------------------------------------
# Construct the S3 bucket object policy
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "kms_cmk_access" {
  count = local.execution_iam_kms_cmk == [] ? 0 : 1
  statement {
    sid       = "KmsCmkAccess"
    effect    = "Allow"
    resources = local.execution_iam_kms_cmk
    actions = [
      "kms:Decrypt"
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Build role policy using data, link to role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecs_kms_cmk_access_role_policy" {
  count  = local.execution_iam_kms_cmk == [] ? 0 : 1
  name   = "EcsKmsCmkAccessExecutionRolePolicy"
  role   = aws_iam_role.ExecutionRole.id
  policy = data.aws_iam_policy_document.kms_cmk_access[0].json
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM - Task role, basic. Append policies to this role for S3, DynamoDB etc.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# Task role assume policy
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Task logging privileges
# ---------------------------------------------------------------------------------------------------------------------
#tfsec:ignore:aws-iam-no-policy-wildcards # can be more restrictive
data "aws_iam_policy_document" "task_permissions" {
  statement {
    effect = "Allow"

    resources = [
      aws_cloudwatch_log_group.CloudWatchLogGroup.arn,
      "${aws_cloudwatch_log_group.CloudWatchLogGroup.arn}:*"
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Task permissions to allow ECS Exec command
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "task_ecs_exec_policy" {
  count = var.enable_ecs_exec ? 1 : 0

  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Task Role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "log-permissions"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_permissions.json
}

resource "aws_iam_role_policy" "ecs_exec_inline_policy" {
  count = var.enable_ecs_exec ? 1 : 0

  name   = "ecs-exec-permissions"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_ecs_exec_policy[0].json
}

# ---------------------------------------------------------------------------------------------------------------------
# required task role access for ecs exec
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "kms_cmk_access_for_ecs_exec" {
  count = var.enable_ecs_exec ? 1 : 0
  statement {
    sid       = "KmsCmkAccess"
    effect    = "Allow"
    resources = [data.aws_kms_key.solution_key[0].arn]
    actions = [
      "kms:Decrypt"
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Build role policy using data, link to role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecs_kms_cmk_access_task_role_policy" {
  count  = var.enable_ecs_exec ? 1 : 0
  name   = "EcsKmsCmkAccessTaskRolePolicy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.kms_cmk_access_for_ecs_exec[0].json
}