module "msk" {
  source  = "terraform-aws-modules/msk-kafka-cluster/aws"
  version = "~> 3.0"

  name = var.project_name

  kafka_version = "3.8.x"

  number_of_broker_nodes    = 3
  broker_node_instance_type = "kafka.t3.small"

  broker_node_client_subnets  = module.vpc.private_subnets
  broker_node_security_groups = [aws_security_group.msk.id]

  broker_node_storage_info = {
    ebs_storage_info = {
      volume_size = 10
    }
  }

  encryption_in_transit_client_broker = "PLAINTEXT"

  client_authentication = {
    unauthenticated = true
  }

  configuration_server_properties = {
    "auto.create.topics.enable" = true
  }
}

resource "aws_security_group" "msk" {
  vpc_id      = module.vpc.vpc_id
  name        = "${var.project_name}-msk"
  description = "TF: Security group used by the ${var.project_name} MSK cluster."

  ingress {
    description     = "TF: Allow Kafka broker traffic on port 9092."
    protocol        = "tcp"
    from_port       = 9092
    to_port         = 9092
    security_groups = [aws_security_group.node.id]
  }

  egress {
    description = "TF: Allow all outbound traffic."
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-msk"
  }
}
