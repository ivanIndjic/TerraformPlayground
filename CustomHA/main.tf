
provider "aws" {
	region = "eu-west-1"
	profile = "ivan"
} 

resource "aws_vpc" "main" {
	cidr_block = "10.0.0.0/16"
	instance_tenancy = "default"
}

resource "aws_subnet" "private1" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.0.1.0/24"
	availability_zone = "eu-west-1a"
	tags = {
	  Name = "Private-subnet-1"
	  Desc = "Private subnet in the eu-west-1a AZ"
	}

}

resource "aws_subnet" "public1" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.0.4.0/24"
	map_public_ip_on_launch = true
	availability_zone = "eu-west-1a"
	tags = {
	  Name = "Public-subnet-1"
	  Desc = "Public subnet in the eu-west-1a AZ"
	}
}

resource "aws_subnet" "private2" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.0.3.0/24"
	availability_zone = "eu-west-1b"
	tags = {
	  name = "Private-subnet-2"
	  desc = "Private subnet in the eu-west-1b AZ"
	}

}

resource "aws_subnet" "public2" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.0.2.0/24"
	availability_zone = "eu-west-1b"
	map_public_ip_on_launch = true
	tags = {
	  name = "Public-subnet-2"
	  desc = "Public subnet in the eu-west-1b AZ"
	}
}

resource "aws_internet_gateway" "aig" {
	vpc_id = aws_vpc.main.id
	tags = {
	  name = "internet-gateway"	
	}	
}

resource "aws_route_table" "table" {
	depends_on = [aws_internet_gateway.aig, aws_vpc.main]
	vpc_id = aws_vpc.main.id
	route {
	  cidr_block = "0.0.0.0/0"
	  gateway_id = aws_internet_gateway.aig.id
	}
	tags = {
	  Name = "IG-route-table"
	}
}

#Connect public subnet 1 to internet using route table and igw as target

resource "aws_route_table_association" "associate_route_table_to_public_subnet1" {
	depends_on = [aws_internet_gateway.aig, aws_subnet.public1]
	subnet_id = aws_subnet.public1.id
	route_table_id = aws_route_table.table.id
}

#Connect public subnet 2 to internet using route table and igw as target

resource "aws_route_table_association" "associate_route_table_to_public_subnet2" {
	depends_on = [aws_internet_gateway.aig, aws_subnet.public2]
	subnet_id = aws_subnet.public2.id
	route_table_id = aws_route_table.table.id
}

#Create elastic ip because One-Way NAT requires it

resource "aws_eip" "eip" {
	vpc = true
}

#Create NAT gateway for db in private subnet so they can have access to internet but not vice-versa

resource "aws_nat_gateway" "nat_gateway" {
	depends_on = [aws_subnet.public1, aws_eip.eip]
	allocation_id = aws_eip.eip.id
	subnet_id = aws_subnet.public1.id
	tags = {
	  Name = "nat-gateway"
	}
}

#Route traffic from private subnet to NAT gateway

resource "aws_route_table" "private_route_table" {
	depends_on = [aws_vpc.main, aws_subnet.private1, aws_nat_gateway.nat_gateway]
	vpc_id = aws_vpc.main.id
	route {
	  cidr_block = "0.0.0.0/0"
	  gateway_id = aws_nat_gateway.nat_gateway.id
	}
	tags = {
	  Name = "Nat-gateway-route-table"
	}
}

#Associate nat gateway route table to private subnet 1 so instances in private subnet 1 can have internet connection

resource "aws_route_table_association" "route_traffic_to_private_subnet1" {
	depends_on = [aws_vpc.main, aws_subnet.private1, aws_route_table.private_route_table]
	subnet_id = aws_subnet.private1.id
	route_table_id = aws_route_table.private_route_table.id
}


#Associate nat gateway route table to private subnet 2 so instances in private subnet 2 can have internet connection

resource "aws_route_table_association" "route_traffic_to_private_subnet2" {
	depends_on = [aws_vpc.main, aws_subnet.private2, aws_route_table.private_route_table]
	subnet_id = aws_subnet.private2.id
	route_table_id = aws_route_table.private_route_table.id
}


resource "aws_vpc_endpoint" "s3_endpoint" {
	vpc_id = aws_vpc.main.id
	vpc_endpoint_type = "Gateway"
	service_name = "com.amazonaws.eu-west-1.s3"
	route_table_ids =[aws_route_table.table.id, aws_route_table.private_route_table.id]
}

#Create Network access control list for public subnets

resource "aws_network_acl" "public_acl" {
	vpc_id = aws_vpc.main.id
	subnet_ids = [aws_subnet.public1.id, aws_subnet.public2.id]
	ingress {
	  rule_no = 100
	  protocol = "tcp"
	  from_port = 80
	  to_port = 80
	  action = "allow"
	  cidr_block = "0.0.0.0/0"
	}
	ingress {
	  rule_no = 110
	  protocol = "tcp"
          from_port = 443
          to_port = 443
	  action = "allow"
          cidr_block = "0.0.0.0/0"
	}
	ingress {
	  rule_no = 120
	  protocol = "tcp"
          from_port = 22
          to_port = 22
	  action = "allow"
          cidr_block = "0.0.0.0/0"
	}
	ingress {
	  rule_no = 130
	  protocol = "tcp"
          from_port = 1024
          to_port = 65535
	  action = "allow"
          cidr_block = "0.0.0.0/0"
	}
	
	egress {
	  rule_no = 100
          protocol = "tcp"
	  from_port = 80
	  to_port = 80
	  action = "allow"
	  cidr_block = "0.0.0.0/0"
	}
	
	egress {
	  rule_no = 110
          protocol = "tcp"
	  from_port = 443
	  to_port = 443
	  action = "allow"
	  cidr_block = "0.0.0.0/0"
	}
	
	egress {
	  rule_no = 120
          protocol = "tcp"
	  from_port = 22
	  to_port = 22
	  action = "allow"
	  cidr_block = "10.0.1.0/24"
	}
	
	egress {
	  rule_no = 130
          protocol = "tcp"
	  from_port = 3306
	  to_port = 3306
	  action = "allow"
	  cidr_block = "10.0.1.0/24"
	}
	
	egress {
	  rule_no = 140
          protocol = "tcp"
	  from_port = 22
	  to_port = 22
	  action = "allow"
	  cidr_block = "10.0.3.0/24"
	}
	
	egress {
	  rule_no = 150
          protocol = "tcp"
	  from_port = 3306
	  to_port = 3306
	  action = "allow"
	  cidr_block = "10.0.3.0/24"
	}
	
	egress {
	  rule_no = 160
          protocol = "tcp"
	  from_port = 1024
	  to_port = 65535
	  action = "allow"
	  cidr_block = "0.0.0.0/0"
	}
	
}
#Create network access list for private subnets
resource "aws_network_acl" "private_acl" {
	vpc_id = aws_vpc.main.id
	subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
  	ingress {
    	  protocol   = "tcp"
    	  rule_no    = 100
    	  action     = "allow"
    	  cidr_block = "10.0.4.0/24"
    	  from_port  = 3306
    	  to_port    = 3306
  	}
	
  	ingress {
    	  protocol   = "tcp"
    	  rule_no    = 110
    	  action     = "allow"
    	  cidr_block = "10.0.4.0/24"
    	  from_port  = 22
    	  to_port    = 22             
  	}
	
  	ingress {
    	  protocol   = "tcp"
    	  rule_no    = 120
    	  action     = "allow"
    	  cidr_block = "10.0.2.0/24"
    	  from_port  = 3306
    	  to_port    = 3306
  	}

  	ingress {
    	  protocol   = "tcp"
    	  rule_no    = 130
    	  action     = "allow"
    	  cidr_block = "10.0.2.0/24"
    	  from_port  = 22
    	  to_port    = 22
  	}
  	ingress {
    	  protocol   = "tcp"
    	  rule_no    = 140
    	  action     = "allow"
    	  cidr_block = "0.0.0.0/0"
    	  from_port  = 32768
    	  to_port    = 61000
  	}

	egress {
	  protocol = "tcp"
	  rule_no = 100
	  action = "allow"
	  cidr_block = "0.0.0.0/0"
	  from_port = 80
	  to_port = 80
	}

	egress {
	  protocol = "tcp"
	  rule_no = 110
	  action = "allow"
	  cidr_block = "0.0.0.0/0"
	  from_port = 443
	  to_port = 443
	}


	egress {
	  protocol = "tcp"
	  rule_no = 120
	  action = "allow"
	  cidr_block = "10.0.4.0/24"
	  from_port = 32768
	  to_port = 61000
	}


	egress {
	  protocol = "tcp"
	  rule_no = 130
	  action = "allow"
	  cidr_block = "10.0.2.0/24"
	  from_port = 32768
	  to_port = 61000
	}


}

resource "aws_security_group" "terraform_web_server_security_group" {
	name = "terraform_web_server_sercurity_group"
	description = "Security group for webservers in public subnet"
	vpc_id = aws_vpc.main.id
	ingress {
	  description = "Allow tls traffic"
	  from_port = 443
	  to_port = 443
	  protocol = "tcp"
	  cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
	  description = "Allow http traffic"
	  from_port = 80
	  to_port = 80
	  protocol = "tcp"
	  cidr_blocks = ["0.0.0.0/0"]
	}
	
	ingress {
	  description = "Allow ssh traffic from specific ip"
	  from_port = 22
	  to_port = 22
	  protocol = "tcp"
	  cidr_blocks = ["93.86.78.15/32"]
	}
	
	ingress {
	  description = "Allow traffic within group"
	  from_port = 0
	  to_port = 65535
	  protocol = "tcp"
	  self = true
	}
	
	egress {
	  description = "Allow all outbound traffoc"
	  from_port = 0
	  to_port = 65535
	  protocol = "tcp"
	  cidr_blocks = ["0.0.0.0/0"]
	}

}

resource "aws_lb" "alb" {
	name = "Terraform-cross-az-lb"
	load_balancer_type = "application"
	internal = false
	security_groups = [aws_security_group.terraform_web_server_security_group.id]
	subnets = [aws_subnet.public1.id, aws_subnet.public2.id]
}


resource "aws_alb_target_group" "tg" {
	name = "Cstm-Terraform-tg-wp"
	port = 80
	protocol = "HTTP"
	vpc_id = aws_vpc.main.id
	health_check {
	    port = 80
	    healthy_threshold = 5
	    unhealthy_threshold = 2
	    timeout = 10
	    protocol = "HTTP"
	    path = "/"
	    interval = 15
	    matcher = "200,202,300,301,302"

	}

	stickiness {
	  enabled = true
	  type = "lb_cookie"
	  cookie_duration = 100000
	}

}

resource "aws_alb_target_group" "tg-mag" {
	name = "Cstm-Terraform-tg-mgn"
	port = 80
	protocol = "HTTP"
	vpc_id = aws_vpc.main.id
	health_check {
	    port = 80
	    healthy_threshold = 5
	    unhealthy_threshold = 2
	    timeout = 10
	    protocol = "HTTP"
	    path = "/"
	    interval = 15
	    matcher = "200,202,300,301,302"

	}

	stickiness {
	  enabled = true
	  type = "lb_cookie"
	  cookie_duration = 100000
	}

}

resource "aws_lb_listener" "alb_listener" {
	load_balancer_arn = aws_lb.alb.arn
	port = 80
	protocol = "HTTP"
	default_action {
	  type = "forward"
	  target_group_arn = aws_alb_target_group.tg.arn
	}
}

resource "aws_lb_listener_rule" "mag-rule" {
	priority = 100
	listener_arn = aws_lb_listener.alb_listener.arn
	action {
	  type = "forward"
	  target_group_arn = aws_alb_target_group.tg-mag.arn
	}
	condition {
	  path_pattern {
	    values = ["/store/*","/store"]
	   }
	}
}


# resource "aws_lb_listener_rule" "wp-rule" {
#	priority = 110
#	listener_arn = aws_lb_listener.alb_listener.arn
#	action {
#	  type = "forward"
#	  target_group_arn = aws_alb_target_group.tg.arn
#	}
#	condition {
#	  path_pattern {
#	    values = ["/blog/*","/blog"]
#	   }
#	}
#}



resource "aws_launch_configuration" "wordpress-alc" {
	name = "wordpress-lc"
	image_id = "ami-3dba8e4e"
	instance_type = "t2.micro"
	security_groups = [aws_security_group.terraform_web_server_security_group.id]
	key_name = "ivan-keypair"
}

resource "aws_launch_configuration" "magento-alc" {
	name = "magento-lc"
	image_id = "ami-222b3b44"
	instance_type = "t2.micro"
	security_groups = [aws_security_group.terraform_web_server_security_group.id]
	key_name = "ivan-keypair"
}




resource "aws_autoscaling_group" "asg-wordpress" {
	name = "Wp-app-asg"
	max_size = 10
	min_size = 2
	health_check_grace_period = 20
	health_check_type = "ELB"
	vpc_zone_identifier = [aws_subnet.public1.id]
	desired_capacity = 3
	force_delete = true
	launch_configuration = aws_launch_configuration.wordpress-alc.name
}


resource "aws_autoscaling_group" "asg-magento" {
	name = "Mgn-app-asg"
	max_size = 5
	min_size = 2
	health_check_grace_period = 20
	health_check_type = "ELB"
	vpc_zone_identifier = [aws_subnet.public2.id]
	desired_capacity = 3
	force_delete = true
	launch_configuration = aws_launch_configuration.magento-alc.name
}



resource "aws_autoscaling_attachment" "wordpress-attachment" {
	autoscaling_group_name = aws_autoscaling_group.asg-wordpress.name
	alb_target_group_arn = aws_alb_target_group.tg.arn
}


resource "aws_autoscaling_attachment" "magento-attachment" {
	autoscaling_group_name = aws_autoscaling_group.asg-magento.name
	alb_target_group_arn = aws_alb_target_group.tg-mag.arn
}

resource "aws_security_group" "terraform_db_sg_group" {
	vpc_id = aws_vpc.main.id
	name = "Aurora-db-sg"
	ingress {
	  protocol = "tcp"
	  from_port = 3306
          to_port = 3306
	  security_groups = [aws_security_group.terraform_web_server_security_group.id]
	  description = "Allow traffic on port 3306 from web servers"	
	}
	egress {
	  protocol = "tcp"
	  from_port = 80
          to_port = 80
          cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
	  protocol = "tcp"
	  from_port = 443
          to_port = 443
          cidr_blocks = ["0.0.0.0/0"]
	}
	
}

resource "aws_security_group_rule" "outbound-from-web-sg" {
	type = "egress"
	from_port = 3306
	to_port = 3306
	protocol = "tcp"
	security_group_id = aws_security_group.terraform_web_server_security_group.id
	source_security_group_id = aws_security_group.terraform_db_sg_group.id
}

resource "aws_db_subnet_group" "rds_subnet_group" {
	name = "rds-subnet-group"
	subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
}

resource "aws_db_instance" "rds" {
	allocated_storage = 5
	storage_type = "gp2"
	engine = "mysql"
	engine_version = "5.7"
	instance_class = "db.t2.micro"
	name = "test"
	identifier = "mysql-db-instance"
	username = "ivan"
	password = "ivanindjic"
	parameter_group_name = "default.mysql5.7"
	apply_immediately = true
	#availability_zone = "eu-west-1a"
	db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
	multi_az = true
	backup_retention_period = 7
	publicly_accessible = false
	port = 3306
	vpc_security_group_ids = [aws_security_group.terraform_db_sg_group.id]
}

resource "aws_db_instance" "read_replica" {
	depends_on = [aws_db_instance.rds]
	replicate_source_db = aws_db_instance.rds.arn
	allocated_storage = 5
	backup_retention_period = 7
	storage_type = "gp2"
	identifier = "mysql-db-read-replica"
	username = "ivan"
	password = "ivanindjic"
	parameter_group_name = "default.mysql5.7"
	apply_immediately = true
	engine = "mysql"
	availability_zone = "eu-west-1b"
	engine_version = "5.7"
	instance_class = "db.t2.micro"
	publicly_accessible = false
	port = 3306
	db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
	vpc_security_group_ids = [aws_security_group.terraform_db_sg_group.id]
}
