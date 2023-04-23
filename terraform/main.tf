resource "aws_vpc" "myVOIP" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "subzero" {
  vpc_id     = aws_vpc.myVOIP.id
  cidr_block = var.cidr_subzero_1 
map_public_ip_on_launch = true
availability_zone = var.subnet12_az
  tags = {
    Name = "subzero"
  }
}

resource "aws_subnet" "subone" {
  vpc_id     = aws_vpc.myVOIP.id
  cidr_block = var.cidr_subone_2 
  map_public_ip_on_launch = true
  availability_zone = var.subnet13_az

  tags = {
    Name = "subone"
  }
}

resource "aws_subnet" "subtwo" {
  vpc_id     = aws_vpc.myVOIP.id
  cidr_block = var.cidr_subtwo_3
  availability_zone = var.subnet14_az

  tags = {
    Name = "subtwo"
  }
}

resource "aws_subnet" "subthree" {
  vpc_id     = aws_vpc.myVOIP.id
  cidr_block = var.cidr_subthree_4 
  availability_zone = var.subnet15_az

  tags = {
    Name = "subthree"
  }
}

resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.myVOIP.id

  tags = {
    Name = "prod-igw"
  }
}

resource "aws_route_table" "prod-pub-rt" {
  vpc_id = aws_vpc.myVOIP.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-igw.id
  }

  tags = {
    Name = "prod-pub-rt"
  }
}

resource "aws_route_table" "prod-priv-rt" {
  vpc_id = aws_vpc.myVOIP.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.chuckskin.id
  }

  tags = {
    Name = "prod-pub-rt"
  }
}

resource "aws_security_group" "web-dmz" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myVOIP.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.myVOIP.cidr_block]
    
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

   ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-dmz"
  }
} 

resource "aws_nat_gateway" "chuckskin" {
  allocation_id = aws_eip.ezp.id
  subnet_id     = aws_subnet.subzero.id

  tags = {
    Name = "demarko-nat"
  }
}

resource "aws_eip" "ezp" {
  vpc = true
  tags = {
   Name = "demarko"
  }
}

resource "aws_route_table_association" "rt-association-pub1" {
  subnet_id      = aws_subnet.subzero.id
  route_table_id = aws_route_table.prod-pub-rt.id
}

resource "aws_route_table_association" "rt-association-pub2" {
  subnet_id      = aws_subnet.subone.id
  route_table_id = aws_route_table.prod-pub-rt.id
}

resource "aws_route_table_association" "rt-association-priv3" {
  subnet_id      = aws_subnet.subtwo.id
  route_table_id = aws_route_table.prod-priv-rt.id
}

resource "aws_route_table_association" "rt-association-priv4" {
  subnet_id      = aws_subnet.subthree.id
  route_table_id = aws_route_table.prod-priv-rt.id
}

resource "aws_instance" "my-test1" {
  ami           = "ami-006dcf34c09e50022" # us-east-1
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web-dmz.id]
  associate_public_ip_address = true
  key_name = "rss"
  subnet_id = aws_subnet.subzero.id
  user_data = "${file("userdata.sh")}"
  tags = {
    Name = "my-testwebserver"
  }
}

resource "aws_launch_configuration" "bebeto" {
  name_prefix   = "learn-how-to-code-asg-"
  image_id      = "ami-006dcf34c09e50022"
  instance_type = "t2.micro"
  user_data = file("userdata.sh")
  security_groups = [aws_security_group.web-dmz.id]
  key_name = "rss"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "minamino" {
  name                 = "terraform-asg-trivago"
  launch_configuration = aws_launch_configuration.bebeto.name
  min_size             = 1
  max_size             = 2
  desired_capacity = 1
  vpc_zone_identifier = [aws_subnet.subzero.id, aws_subnet.subone.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "myNLB" {
  name               = "test-my-stuff"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subzero.id, aws_subnet.subone.id]
  security_groups = [aws_security_group.web-dmz.id]

  enable_deletion_protection = true
}


resource "aws_lb_target_group" "my-ASG-target" {
  name = "learn-to-target"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myVOIP.id
  }


resource "aws_lb_listener" "webserver" {
  load_balancer_arn = aws_lb.myNLB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.my-ASG-target.arn
    }
  }

  resource "aws_autoscaling_attachment" "auto-group" {
  autoscaling_group_name = aws_autoscaling_group.minamino.id
  alb_target_group_arn = aws_lb_target_group.my-ASG-target.arn
  }


resource "aws_ecr_repository" "demarko" {
  name                 = "demarko12"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

 





