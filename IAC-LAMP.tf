terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16.2"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "deployer_private_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "deployer-key.pem"
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# Define the security group for the EC2 instance
resource "aws_security_group" "aws-sg-webserver" {
  name        = "aws-sg-webserver"
  description = "Allow inbound traffic from port 22, 80"
  #vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
ingress {
    description = "Allow incoming SSH connections"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
egress {
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]

 #tags = {
 #    Name = "webserver-sg"
 # }
}
}


resource "aws_instance" "web-Server" {
  ami           = data.aws_ami.amazon_linux-2.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.aws-sg-webserver.id]
  user_data = file("userdata.tpl")
  tags = {
    Name = "web-Server"
  }
}

resource "aws_launch_template" "aws-launch-aws_launch_template" {
  name = "aws-launch-template"
  image_id = data.aws_ami.amazon_linux-2.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.aws-sg-webserver.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "aws-webserver"
    }
  }
  user_data = filebase64("userdata.tpl")
}
 
#Auto Scaling Group of 2 minimum instance in 3 availability zones
resource "aws_autoscaling_group" "aws-aws-autoscaling-group" {  
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  min_size = 2
  max_size = 3
  desired_capacity = 2
  
  launch_template {
    id = aws_launch_template.aws-launch-aws_launch_template.id
    version = "$Latest"
  }
}
