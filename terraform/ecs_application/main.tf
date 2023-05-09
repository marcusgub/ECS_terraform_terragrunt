module "ecs_task_execution_role" {
  source = "../service_role"
  policy_document = {
    actions = var.ecs_task_execution_role.policy_document.actions
    effect = var.ecs_task_execution_role.policy_document.effect
    type = var.ecs_task_execution_role.policy_document.type
    identifiers = var.ecs_task_execution_role.policy_document.identifiers
  }
  iam_role_name = var.ecs_task_execution_role.iam_role_name
  iam_policy_arn = var.ecs_task_execution_role.iam_policy_arn
}

## --------------------------------------------------------------------------- ##

resource "aws_ecs_task_definition" "ecs_task" {
  family                    = var.ecs_task.family
  container_definitions     = jsonencode([
    {
      name                  = var.ecs_task.container_image_name
      image                 = var.ecs_task.container_image
      memory                = var.ecs_task.memory
      cpu                   = var.ecs_task.cpu
      restart_policy        = "RESTART_AFTER_FAILURE"
      essential             = true
      placement_constraints =[
        {
          type       = "distinctInstance"
          expression = "attribute:ecs.availability-zone"
        }
      ]
      portMappings          = [
        {
          containerPort     = 80
          hostPort          = 80
        }
      ]
    }
  ])
  network_mode              = var.ecs_task.network_mode
  execution_role_arn        = module.ecs_task_execution_role.iam_role_arn
  requires_compatibilities  = ["FARGATE"]
  cpu                       = 256
  memory                    = 512
}  

resource "aws_ecs_service" "ecs_service" {
  name               = var.ecs_service.name
  cluster            = var.ecs_service.cluster
  task_definition    = aws_ecs_task_definition.ecs_task.arn
  launch_type        = var.ecs_service.launch_type
  desired_count      = var.ecs_service.desired_count

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx.arn
    container_name   = var.ecs_task.container_image_name
    container_port   = var.ecs_task.container_image_port
  }

  network_configuration {
    assign_public_ip = true

    security_groups = [
      var.ecs_service.egress_all_id,
      aws_security_group.ingress_api.id,
    ]

    subnets = var.ecs_service.private_subnets
  }
}

resource "aws_lb_target_group" "nginx" {
  name        = "nginx"
  port        = var.ecs_task.container_image_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled = true
    path    = "/"
  }
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = var.alb_arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

resource "aws_security_group" "ingress_api" {
  name        = "ingress-api"
  description = "Allow ingress to API"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.ecs_task.container_image_port
    to_port     = var.ecs_task.container_image_port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## --------------------------------------------------------------------------- ##

module "ecs_autoscale_role" {
  source = "../service_role"
  policy_document = {
    actions = var.ecs_autoscale_role.policy_document.actions
    effect = var.ecs_autoscale_role.policy_document.effect
    type = var.ecs_autoscale_role.policy_document.type
    identifiers = var.ecs_autoscale_role.policy_document.identifiers
  }
  iam_role_name = var.ecs_autoscale_role.iam_role_name
  iam_policy_arn = var.ecs_autoscale_role.iam_policy_arn
}

## --------------------------------------------------------------------------- ##

resource "aws_appautoscaling_target" "ecs_target" {
  min_capacity       = 1
  max_capacity       = 6
  resource_id        = "service/${var.ecs_service.cluster}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = module.ecs_autoscale_role.iam_role_arn
}

resource "aws_appautoscaling_policy" "appautoscaling_policy_cpu" {
  name               = "application-scale-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "appautoscaling_policy_memory" {
  name               = "application-scale-policy-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
}