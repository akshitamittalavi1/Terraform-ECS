# ecs.tf | Elastic Container Service Cluster and Tasks Configuration

resource "aws_ecs_cluster" "aws-ecs-cluster" {
  name = "${var.app_name}-${var.app_environment}-cluster"
  tags = {
    Name        = "${var.app_name}-ecs"
    Environment = var.app_environment
  }
}

resource "aws_cloudwatch_log_group" "log-group" {
  name = "${var.app_name}-${var.app_environment}-logs"

  tags = {
    Application = var.app_name
    Environment = var.app_environment
  }
}

data "template_file" "env_vars" {
  template = file("env_vars.json")
}

resource "aws_ecs_task_definition" "aws-ecs-task" {
  family = "${var.app_name}-task"
  requires_compatibilities = ["FARGATE","EC2"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "${var.app_name}-${var.app_environment}-container",
      "image": "nginx:latest",
      "entryPoint": [],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.log-group.id}",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "${var.app_name}-${var.app_environment}"
        }
      },
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "cpu": 256,
      "memory": null,
      "memoryReservation": 512,
      "networkMode": "awsvpc"
    }
  ]
  TASK_DEFINITION

  tags = {
    Name        = "${var.app_name}-ecs-td"
    Environment = var.app_environment
  }
}

data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.aws-ecs-task.family
}

resource "aws_ecs_service" "aws-ecs-service" {
  name                 = "${var.app_name}-${var.app_environment}-ecs-service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster.id
  task_definition      = "${aws_ecs_task_definition.aws-ecs-task.family}:${max(aws_ecs_task_definition.aws-ecs-task.revision, data.aws_ecs_task_definition.main.revision)}"
  enable_execute_command = true
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets          = [ var.subnet-id-1 ]
    assign_public_ip = true
    security_groups = [
      var.security-group
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "${var.app_name}-${var.app_environment}-container"
    container_port   = 80  
    }

  depends_on = [aws_lb_listener.listener]
}

