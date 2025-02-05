# Create a VPC
resource "aws_vpc" "nandovpc" {
    cidr_block = var.cidr
}


# Create Subnets In Two Availability Zones
resource "aws_subnet" "croydon" {
    vpc_id                      = aws_vpc.nandovpc.id
    cidr_block                  = "10.0.1.0/24"
    availability_zone           = "eu-west-2a"
    map_public_ip_on_launch     = true
}

resource "aws_subnet" "chelsea" {
    vpc_id                      = aws_vpc.nandovpc.id
    cidr_block                  = "10.0.2.0/24"
    availability_zone           = "eu-west-2b"
    map_public_ip_on_launch     = true
}

# Create An Internet GateWay
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.nandovpc.id
}

# Create A Route Table  
resource "aws_route_table" "routetable" {
    vpc_id = aws_vpc.nandovpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
}

# Create A Security Group
resource "aws_route_table_association" "route_table_ascotion1" {
    subnet_id      = aws_subnet.croydon.id
    route_table_id = aws_route_table.routetable.id
}

resource "aws_route_table_association" "route_table_ascotion2" {
    subnet_id      = aws_subnet.chelsea.id
    route_table_id = aws_route_table.routetable.id
}

# Create Security Group
resource "aws_security_group" "nando-sg" {
    name        = "web"
    description = "Allow TLS inbound traffic and all outbound traffic"
    vpc_id      = aws_vpc.nandovpc.id

    ingress {
        description = "HTTP from VPC"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "All outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }   

    tags = {
        Name = "nando-sg"
    }
}

# Create S3 Bucket
resource "aws_s3_bucket" "nando-bucket" {
    bucket = "nando-bucket09731"
}

# Create EC2 Instances
resource "aws_instance" "croydon-instance" {
    ami                     = "ami-091f18e98bc129c4e"
    instance_type           = "t2.micro"
    vpc_security_group_ids  = [aws_security_group.nando-sg.id]
    subnet_id               = aws_subnet.croydon.id
    user_data               = file("userdata.sh") 
}

resource "aws_instance" "chelsea-instance" {
    ami                     = "ami-091f18e98bc129c4e"
    instance_type           = "t2.micro"
    vpc_security_group_ids  = [aws_security_group.nando-sg.id]
    subnet_id               = aws_subnet.chelsea.id
    user_data               = file("userdata1.sh") 
}

# Create Application Load Balancer
resource "aws_lb" "nando-lb" {
    name               = "nando-lb"
    internal           = false
    load_balancer_type = "application"

    security_groups    = [aws_security_group.nando-sg.id]
    subnets            = [aws_subnet.croydon.id, aws_subnet.chelsea.id]

    tags = {
        Name = "Web"
    }
}

# Create ALB Target Group
resource "aws_lb_target_group" "target-group" {
    name     = "nando-target-group"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.nandovpc.id

    health_check {
        path                = "/"
        port                = "traffic-port"
    }
}

# Associate ALB Target Group with ALB
resource "aws_lb_target_group_attachment" "target-attach1" {
    target_group_arn = aws_lb_target_group.target-group.arn
    target_id        = aws_instance.croydon-instance.id
    port             = 80
}

resource "aws_lb_target_group_attachment" "target-attach2" {
    target_group_arn = aws_lb_target_group.target-group.arn
    target_id        = aws_instance.chelsea-instance.id
    port             = 80
}

# Create ALB Listener
resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.nando-lb.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.target-group.arn
    }
}

output "loadbalancerdns" {
    value = aws_lb.nando-lb.dns_name
}