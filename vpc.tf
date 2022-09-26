resource "aws_vpc" "vpc_london" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${terraform.workspace}-vpc-london"
  }

}

output "vpc_london" {
  value = aws_vpc.vpc_london.id
}

#Create public subnet # 1 in eu-west-2
resource "aws_subnet" "pub-subnet_1" {
  availability_zone       = "eu-west-2a"
  vpc_id                  = aws_vpc.vpc_london.id
  cidr_block              = "10.0.100.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "${terraform.workspace}-pub-subnet_1"
  }

}

#Create subnet #2  in eu-west-2
resource "aws_subnet" "pub-subnet_2" {
  vpc_id                  = aws_vpc.vpc_london.id
  availability_zone       = "eu-west-2b"
  cidr_block              = "10.0.200.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "${terraform.workspace}-pub-subnet_2"
  }

}

#Create IGW in eu-west-2
resource "aws_internet_gateway" "london-igw" {
  vpc_id = aws_vpc.vpc_london.id
  tags = {
    Name = "london-igw"
  }
}

resource "aws_route_table" "pub-subnet-RT" {
  vpc_id = aws_vpc.vpc_london.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.london-igw.id
  }

  tags = {
    Name = "pub-subnet-RT"
  }
}

resource "aws_route_table_association" "pub-subnet1-RTA" {
  subnet_id      = aws_subnet.pub-subnet_1.id
  route_table_id = aws_route_table.pub-subnet-RT.id
}

resource "aws_route_table_association" "pub-subnet2-RTA" {
  subnet_id      = aws_subnet.pub-subnet_2.id
  route_table_id = aws_route_table.pub-subnet-RT.id
}

resource "aws_launch_configuration" "instance" {
  image_id        = "ami-00785f4835c6acf64"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance-sg.id]
  user_data       = <<-EOF
	     #!/bin/bash
             sudo yum install -y httpd
             systemctl start httpd
             systemctl enable httpd
             echo "Hello World" >> /var/www/html/index.html
             EOF
}

resource "aws_autoscaling_group" "instance-asg" {
  name                 = "instance-asg"
  launch_configuration = aws_launch_configuration.instance.name
  vpc_zone_identifier  = data.aws_subnets.subnets_london.ids
  target_group_arns    = [aws_lb_target_group.lb-tgroup.arn]
  health_check_type    = "EC2"
  min_size             = 1
  max_size             = 2
  tag {
    key                 = "Name"
    value               = "instance"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_subnets" "subnets_london" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.vpc_london.id]
  }
}

resource "aws_lb" "instance-lb" {
  name               = "instance-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.subnets_london.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.instance-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "lb-tgroup" {
  name     = "lb-tgroup"
  port     = var.http_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_london.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "lb_listener_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tgroup.arn
  }
}

resource "aws_security_group" "lb_sg" {
  name   = "lb_sg"
  vpc_id = aws_vpc.vpc_london.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance-sg" {
  name   = "instance-sg"
  vpc_id = aws_vpc.vpc_london.id
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.lb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "alb_dns_name" {
  value = aws_lb.instance-lb.dns_name
}

output "london_subnets" {
  value = data.aws_subnets.subnets_london.ids
}
