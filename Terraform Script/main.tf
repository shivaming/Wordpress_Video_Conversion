#---------------------------------
#VPC
#---------------------------------
resource "aws_vpc" "Main" {               
   cidr_block       = var.main_vpc_cidr   
   instance_tenancy = "default"
   enable_dns_hostnames = true
   tags = {
    Name = "custom-vpc"
  }  
 }
 
 resource "aws_internet_gateway" "IGW" {    
    vpc_id =  aws_vpc.Main.id              
 }

 resource "aws_subnet" "public1" { 
   vpc_id =  aws_vpc.Main.id
   cidr_block = var.public_subnet1
   availability_zone = "us-east-1a"
  tags = {
    Name = "Public-Subnet-1"
  }        
 }

 resource "aws_subnet" "public2" { 
   vpc_id =  aws_vpc.Main.id
   cidr_block = var.public_subnet2
   availability_zone = "us-east-1b"
  tags = {
    Name = "Public-Subnet-2"
  }        
 }
                  
 resource "aws_subnet" "private1" { 
   vpc_id =  aws_vpc.Main.id
   cidr_block = var.private_subnet1
   availability_zone = "us-east-1a"
  tags = {
    Name = "Private-Subnet-1"
  }        
 }

 resource "aws_subnet" "private2" { 
   vpc_id =  aws_vpc.Main.id
   cidr_block = var.private_subnet2
   availability_zone = "us-east-1b"
  tags = {
    Name = "Private-Subnet-2"
  }        
 }

 resource "aws_route_table" "PublicRT" {  
    vpc_id =  aws_vpc.Main.id
         route {
    cidr_block = "0.0.0.0/0"              
    gateway_id = aws_internet_gateway.IGW.id
     }
 }

resource "aws_route_table" "PrivateRT" {    
   vpc_id = aws_vpc.Main.id
   route {
   cidr_block = "0.0.0.0/0"             
   nat_gateway_id = aws_nat_gateway.NATgw.id
   }
 }

 resource "aws_route_table_association" "PublicRTassociation1" {
    subnet_id = aws_subnet.public1.id
    route_table_id = aws_route_table.PublicRT.id
 }
resource "aws_route_table_association" "PublicRTassociation2" {
    subnet_id = aws_subnet.public2.id
    route_table_id = aws_route_table.PublicRT.id
 }

 resource "aws_route_table_association" "PrivateRTassociation1" {
    subnet_id = aws_subnet.private1.id
    route_table_id = aws_route_table.PrivateRT.id
 }

 resource "aws_route_table_association" "PrivateRTassociation2" {
    subnet_id = aws_subnet.private2.id
    route_table_id = aws_route_table.PrivateRT.id
 }
 resource "aws_eip" "nateIP" {
   vpc   = true
 }

 resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.public1.id
 }

# ----------------------
# Security Group
# ----------------------

resource "aws_security_group" "ec2" {
  name        = "EC2-sg"
  description = "Allow efs outbound traffic"
  vpc_id      = aws_vpc.Main.id
  ingress {
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 22
     to_port = 22
     protocol = "tcp"
   }
   ingress {
     security_groups = [ aws_security_group.elb.id ]
     from_port = 80
     to_port = 80
     protocol = "tcp"
   }
   ingress {
     security_groups = [ aws_security_group.elb.id ]
     from_port = 443
     to_port = 443
     protocol = "tcp"
   }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "EC2-sg"
  }
}

resource "aws_security_group" "efs" {
   name = "efs-sg"
   description= "Allos inbound efs traffic from ec2"
   vpc_id = aws_vpc.Main.id

   ingress {
     security_groups = [aws_security_group.ec2.id]
     from_port = 2049
     to_port = 2049
     protocol = "tcp"
   }     
        
   egress {
     security_groups = [aws_security_group.ec2.id]
     from_port = 0
     to_port = 0
     protocol = "-1"
   }
   tags = {
    Name = "EFS-sg"
  }
 }

resource "aws_security_group" "rds" {
   name = "rds-sg"
   description= "Allos inbound RDS traffic from ec2"
   vpc_id = aws_vpc.Main.id

   ingress {
     security_groups = [aws_security_group.ec2.id]
     from_port = 3306
     to_port = 3306
     protocol = "tcp"
   }     
        
   egress {
     security_groups = [aws_security_group.ec2.id]
     from_port = 0
     to_port = 0
     protocol = "-1"
   }
   tags = {
    Name = "RDS-sg"
  }
 }

 resource "aws_security_group" "elb" {
   name = "elb-sg"
   description= "Allos inbound elb traffic from route53"
   vpc_id = aws_vpc.Main.id

   ingress {
     cidr_blocks = [ "0.0.0.0/0" ]
     from_port = 443
     to_port = 443
     protocol = "tcp"
   }   
   ingress {
     cidr_blocks = [ "0.0.0.0/0" ]
     from_port = 80
     to_port = 80
     protocol = "tcp"
   }    
        
   egress {
     cidr_blocks = [ "0.0.0.0/0" ]
     from_port = 0
     to_port = 0
     protocol = "-1"
   }
   tags = {
    Name = "ELB-sg"
  }
 }

#-----------------------------
#EFS
#----------------------------

resource "aws_efs_file_system" "efs" {
   creation_token = "efs"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "custom-efs"
   }
 }


resource "aws_efs_mount_target" "efs-mt" {

   file_system_id  = aws_efs_file_system.efs.id
   subnet_id = aws_subnet.private1.id
   security_groups = [aws_security_group.efs.id]
 }

 resource "aws_efs_mount_target" "efs-mt1" {

   file_system_id  = aws_efs_file_system.efs.id
   subnet_id = aws_subnet.private2.id
   security_groups = [aws_security_group.efs.id]
 }

#--------------------------
#RDS
#-------------------------

resource "aws_db_instance" "default" {
  allocated_storage    = 30
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  db_name              = var.name
  username             = var.username
  password             = var.password
  parameter_group_name = var.parameter_group_name
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [ aws_security_group.rds.id ]
  skip_final_snapshot       = true

}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "DB-sg"
  }
}

#--------------------------
#EC2
#-------------------------
resource "aws_instance" "ec2" {
    ami = var.ami
    instance_type = var.instance_type
    subnet_id = aws_subnet.public1.id
    vpc_security_group_ids = [ aws_security_group.ec2.id ]
    key_name= "25"
    associate_public_ip_address = true
    tags= {
        Name = "terraform_ec2"
    }
}

#--------------------------
#ELB
#-------------------------
resource "aws_elb" "classiclb" {
  name               = "classicelb"
  # availability_zones = ["us-east-1a", "us-east-1b"]
  subnets = [aws_subnet.public1.id, aws_subnet.public2.id]
  security_groups = [ aws_security_group.elb.id ]
  

listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 10
  }

  instances                   = [aws_instance.ec2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 300
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "classic-elb"
  }
}

