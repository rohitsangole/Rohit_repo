provider "aws" {
  region = "us-east-1"

}

# VPC
resource "aws_vpc" "rohit_app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "rohit_app_vpc" }
}

# Subnets
resource "aws_subnet" "rohit_public_subnet_1" {
  vpc_id                  = aws_vpc.rohit_app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "rohit_public_subnet_1" }
}

resource "aws_subnet" "rohit_public_subnet_2" {
  vpc_id                  = aws_vpc.rohit_app_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "rohit_public_subnet_2" }
}

resource "aws_subnet" "rohit_private_subnet" {
  vpc_id                  = aws_vpc.rohit_app_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = { Name = "rohit_private_subnet" }
}

# Internet Gateway and Route Table
resource "aws_internet_gateway" "rohit_igw" {
  vpc_id = aws_vpc.rohit_app_vpc.id
}

resource "aws_route_table" "rohit_public_route_table" {
  vpc_id = aws_vpc.rohit_app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rohit_igw.id
  }
}

resource "aws_route_table_association" "rohit_public_subnet_1" {
  subnet_id      = aws_subnet.rohit_public_subnet_1.id
  route_table_id = aws_route_table.rohit_public_route_table.id
}

resource "aws_route_table_association" "rohit_public_subnet_2" {
  subnet_id      = aws_subnet.rohit_public_subnet_2.id
  route_table_id = aws_route_table.rohit_public_route_table.id
}

# Security Groups
resource "aws_security_group" "rohit_public_sg" {
  vpc_id = aws_vpc.rohit_app_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
  tags = { Name = "rohit_public_sg" }
}

resource "aws_security_group" "rohit_private_sg" {
  vpc_id = aws_vpc.rohit_app_vpc.id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.rohit_public_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "rohit_private_sg" }
}

# Autoscaling Group
resource "aws_launch_configuration" "rohit_app_asg_lc" {
  name          = "rohit_asg_launch_config"
  image_id      = "ami-0e2c8caa4b6378d8c" 
  instance_type = "t2.micro"
  security_groups = [aws_security_group.rohit_public_sg.id]
  iam_instance_profile = aws_iam_instance_profile.rohit_app_role_profile.name
}

resource "aws_autoscaling_group" "rohit_app_asg" {
  launch_configuration = aws_launch_configuration.rohit_app_asg_lc.id
  min_size             = 1
  max_size             = 2
  vpc_zone_identifier  = [aws_subnet.rohit_public_subnet_1.id, aws_subnet.rohit_public_subnet_2.id]
  
}

# Single EC2 Instance
resource "aws_instance" "rohit_private_instance" {
  ami           = "ami-0e2c8caa4b6378d8c" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.rohit_private_subnet.id
  security_groups = [aws_security_group.rohit_private_sg.name]
  tags = { Name = "rohit_private_instance" }
}

# Load Balancers
resource "aws_lb" "rohit_app_alb" {
  name            = "rohit-app-alb"
  internal        = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.rohit_public_sg.id]
  subnets         = [aws_subnet.rohit_public_subnet_1.id, aws_subnet.rohit_public_subnet_2.id]
}

resource "aws_lb" "rohit_app_nlb" {
  name            = "rohit-app-nlb"
  internal        = true
  load_balancer_type = "network"
  subnets         = [aws_subnet.rohit_private_subnet.id]
}

# S3 Bucket
# S3 Bucket
resource "aws_s3_bucket" "rohit_app_bucket" {
  bucket = "my-rohit-app-bucket"
  
}

# S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "rohit_app_bucket_ownership_controls" {
  bucket = aws_s3_bucket.rohit_app_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"  # Object ownership set to bucket owner preferred
  }
}

# S3 Bucket ACL
resource "aws_s3_bucket_acl" "rohit_app_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.rohit_app_bucket_ownership_controls]  # Ensure ownership controls are created first

  bucket = aws_s3_bucket.rohit_app_bucket.id
  acl    = "private"  # Apply private ACL
}


resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.rohit_app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "rohit_app_bucket_policy" {
  bucket = aws_s3_bucket.rohit_app_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Deny",
        Principal = "*",
        Action   = "s3:*",
        Resource = [
          "${aws_s3_bucket.rohit_app_bucket.arn}",
          "${aws_s3_bucket.rohit_app_bucket.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

# IAM Role
resource "aws_iam_role" "rohit_app_role" {
  name = "rohit_app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "rohit_s3_access_policy" {
  name        = "rohit_s3-access-policy"
  description = "Policy to provide full access to S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*"],
        Resource = [
          "${aws_s3_bucket.rohit_app_bucket.arn}",
          "${aws_s3_bucket.rohit_app_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rohit_attach_s3_policy" {
  role       = aws_iam_role.rohit_app_role.name
  policy_arn = aws_iam_policy.rohit_s3_access_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "rohit_app_role_profile" {
  name = "rohit_app-role-profile"
  role = aws_iam_role.rohit_app_role.name
}

