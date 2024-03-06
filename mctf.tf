##-----------------------------------
## Description: two-tier architecture
## Author: Steven Laszloffy
## - VPC
## - two public subnets in separate AZs
## - two private subnets in separate AZs
## - RDS MySQL instance
## - Load balancer
## - EC2 instance in each public subnet
##------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.23.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

#target group
resource "aws_lb_target_group" "target" {
  name        = "target"
  depends_on  = [aws_vpc.REQUIEM]
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.REQUIEM.id}"
  health_check {
    interval            = 70
    path                = "/var/www/html/index.html"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 60
    protocol            = "HTTP"
    matcher             = "200,202"
  }
}
resource "aws_lb_target_group_attachment" "acquire_targets_mki" {
  target_group_arn  = aws_lb_target_group.target.arn
  target_id         = aws_instance.CHATTERBOX.id
  port              = 80
}
resource "aws_lb_target_group_attachment" "acquire_targets_mkii" {
  target_group_arn  = aws_lb_target_group.target.arn
  target_id         = aws_instance.ALL_SEEING_EYE.id
  port              = 80
}
##Resources: VPC and subnets ---------------------
resource "aws_vpc" "REQUIEM" {
  cidr_block  = "10.0.0.0/16"
  tags        = {
    Name = "REQUIEM"
  }
}

resource "aws_subnet" "REQ-626-C" {
  vpc_id                  = aws_vpc.REQUIEM.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "REQ-626-C"
  }
}

resource "aws_subnet" "REQ-814-D" {
  vpc_id                  = aws_vpc.REQUIEM.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "REQ-814-D"
  }
}

resource "aws_subnet" "Copernicus_Base" {
  vpc_id                  = aws_vpc.REQUIEM.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = false
  tags                    = {
    Name = "Copernicus_Base"
  }
}

resource "aws_subnet" "Galileo_Base" {
  vpc_id                  = aws_vpc.REQUIEM.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false
  tags                    = {
    Name = "Galileo_Base"
  }
}
##------------------------------------------------

# NETWORKING --------------------------------------------------
# VPC Security group
resource "aws_security_group" "Sentinel" {
  name        = "Sentinel"
  description = "default VPC security group to allow traffic from VPC"
  vpc_id      = aws_vpc.REQUIEM.id
  depends_on  = [
    aws_vpc.REQUIEM
  ]

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
  }
  ingress {
    from_port     = "80"
    to_port       = "80"
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }
  ingress {
    from_port     = "22"
    to_port       = "22"
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Sentinel"
  }
}

# ALB -----------------------------------------------------------------
resource "aws_lb" "guilty-spark" {
  name                = "guilty-spark"
  internal            = false
  load_balancer_type  = "application"
  security_groups     = [aws_security_group.Sentinel.id]
  subnets             = [aws_subnet.REQ-626-C.id,aws_subnet.REQ-814-D.id]
}

# create ALB listener
resource "aws_lb_listener" "guardian" {
  load_balancer_arn = aws_lb.guilty-spark.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.target.arn
  }
}

# security group for ALB
resource "aws_security_group" "Created" {
  name        = "Created"
  description = "security group for the AWS Load Balancer"
  vpc_id      = aws_vpc.REQUIEM.id
  depends_on  = [
    aws_vpc.REQUIEM
  ]

  
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  

  tags = {
    Name = "Created"
  }
}
#-----------------------------------------------------------------------------
# Internet Gateway
resource "aws_internet_gateway" "the-Maw" {
  vpc_id  = aws_vpc.REQUIEM.id
  tags    = {
    Name = "the-Maw"
  }
}
# Routing table
resource "aws_route_table" "maw-coordinates" {
  vpc_id = aws_vpc.REQUIEM.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.the-Maw.id
  } 
  tags = {
    Name = "Maw-Coordinates"
  }
}
# associate the route table to the public subnets
resource "aws_route_table_association" "maw-coord-to-covie-space-a" {
    subnet_id = "${aws_subnet.REQ-626-C.id}"
    route_table_id = "${aws_route_table.maw-coordinates.id}"
}
resource "aws_route_table_association" "maw-coord-to-covie-space-b" {
    subnet_id = "${aws_subnet.REQ-814-D.id}"
    route_table_id = "${aws_route_table.maw-coordinates.id}"
}


# Instances --------------------------------------
# Key Pair (to SSH into the instances if need be)
resource "aws_key_pair" "sacred_icon" {
  key_name = "sacred-icon"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC76YyeZUPP+hlhRiiYirk7genIU/5WzMcOqUH1Plx1vw75+J3D+T4oPxuEmvZQNnnDUAofu1sVamAzsSVkLqisIc3apICrmtqtysLbGV0CvgjkcQy4Rz9ENIazCNCuvLf7c3fbGVvIpcpnagG8sMtYMUNt4i/rGudWbv4z6zkoc2CVpE5dLfYu+lbhl+ObwzVR2fxvzdstt7lIkQpDWjcITSQbv797ZDzJyu4qGsAVKr/AfeSJjQr3LqU7GAtuSaeT5qOBCknPsAuPNgWcUqgbBJqr4/R2TT9NHDc1VlSk3Vll7WdBf3RavDpPWxDEem+bxZu020oEfWusvEo1BWyP"

}
# Web tier Security Group
resource "aws_security_group" "Covenant" {
  name        = "Covenant"
  description = "security group to allow the web tier instances to talk to the outside"
  vpc_id      = aws_vpc.REQUIEM.id
  depends_on  = [
    aws_vpc.REQUIEM
  ]

  ingress {
    from_port       = "0"
    to_port         = "0"
    protocol        = "-1"
    security_groups = [ aws_security_group.Created.id ]
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Covenant"
  }
}
# RDS mySQL
## RDS needs a subnet group, so creating that:
resource "aws_db_subnet_group" "UNSC_TO" {
  name       = "unsc-theatre-of-operations"
  subnet_ids = [aws_subnet.Copernicus_Base.id, aws_subnet.Galileo_Base.id]
}
resource "aws_db_instance" "Didacts_Gift" {
  allocated_storage           = 5
  storage_type                = "gp2"
  engine                      = "mysql"
  engine_version              = "5.7"
  instance_class              = "db.t2.micro"
  db_name                     = "didacts_gift"
  username                    = "reclaimer"
  password                    = "spartan-john117"
  parameter_group_name        = "default.mysql5.7"
  db_subnet_group_name        = aws_db_subnet_group.UNSC_TO.id
  vpc_security_group_ids      = [aws_security_group.Sentinel.id]
  allow_major_version_upgrade = true
  auto_minor_version_upgrade  = true
  backup_retention_period     = 35
  backup_window               = "22:00-23:00"
  maintenance_window          = "Sat:00:00-Sat:03:00"
  multi_az                    = false
  skip_final_snapshot         = true

}
# public instances
resource "aws_instance" "ALL_SEEING_EYE" {
  ami                    = "ami-02d1e544b84bf7502"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.REQ-626-C.id
  #count                  = 1
  vpc_security_group_ids = [aws_security_group.Sentinel.id]
  key_name = aws_key_pair.sacred_icon.id
  user_data              = <<EOF
  #!/bin/bash
  yum update -y
  yum install httpd -y
  service httpd start
  chkconfig httpd on
  instAZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
  usermod -a -G apache ec2-user
  chown -R ec2-user:apache /var/www
  chmod 2775 /var/www
  echo -e "<head><style>body {background-image: url("https://free4kwallpapers.com/uploads/originals/2020/05/06/-halo-infinite-wallpaper.jpg");background-repeat: no-repeat;background-attachment: fixed;background-size: cover;}p {color: #32a852;}</style></head><body><center><h1><p>Welcome to vyprTECH HQ! This is ALL SEEING EYE. We are currently in Availability Zone: AZID</p></h1><img src="https://live.staticflickr.com/65535/52204755191_eeb61d5ccd_o_d.png" alt="programmer avatar" width="200" height="350"></center></body>" >> /var/www/html/index.txt
  sed "s/AZID/$instAZ/" /var/www/html/index.txt > /var/www/html/index.html
  EOF


  tags = {
    Name = "ALL_SEEING_EYE"
  }
}

resource "aws_instance" "CHATTERBOX" {
  ami                     = "ami-02d1e544b84bf7502"
  instance_type           = "t2.micro"
  subnet_id               = aws_subnet.REQ-814-D.id
  #count                   = 1
  vpc_security_group_ids  = [aws_security_group.Sentinel.id]
  key_name = aws_key_pair.sacred_icon.id
  user_data               = <<EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        service httpd start
        chkconfig httpd on
        instAZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
        usermod -a -G apache ec2-user
        chown -R ec2-user:apache /var/www
        chmod 2775 /var/www
        echo -e "<head><style>body {background-image: url("https://free4kwallpapers.com/uploads/originals/2020/05/06/-halo-infinite-wallpaper.jpg");background-repeat: no-repeat;background-attachment: fixed;background-size: cover;}p {color: #32a852;}</style></head><body><center><h1><p>Welcome to vyprTECH HQ! This is CHATTERBOX. We are currently in Availability Zone: AZID</p></h1><img src="https://live.staticflickr.com/65535/52204755191_eeb61d5ccd_o_d.png" alt="programmer avatar" width="200" height="350"></center></body>" >> /var/www/html/index.txt
        sed "s/AZID/$instAZ/" /var/www/html/index.txt > /var/www/html/index.html
        EOF
  tags = {
    Name = "CHATTERBOX"
  }
}
##---------------------------------------------

#OUTPUTS
output "threefourthree-guilty-spark_dns" {
  description = "DNS of 343 Guilty Spark load balancer"
  value       = aws_lb.guilty-spark.dns_name
}

