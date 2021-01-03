provider "aws" {
	region = "eu-west-1"
	profile = "ivan"

}

variable "vpc_id" {
	type = string
	default = "vpc-4c6da235"
}

resource "aws_security_group" "my-security-group" {
	name = "ivan-demo-sg"
	description = "My first security group"
	vpc_id = "vpc-4c6da235"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
		
	}
	
	egress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

variable "my-ami" {
	type = string
	default = "ami-015232c01a82b847b"
}


resource "aws_instance" "my-instance" {
	ami = "${var.my-ami}"
	instance_type = "t2.micro"
	key_name = "ivan-keypair"
	vpc_security_group_ids = ["${aws_security_group.my-security-group.id}"] 
 	tags = {
		production = "Dev"
	}



}
