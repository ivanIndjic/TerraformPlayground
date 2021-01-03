provider "aws" {
	region = "eu-west-1"
	profile = "ivan"
}

resource "aws_alb_target_group" "tg" {
	name = "Terraform-target-group"
	port = 80
	protocol = "HTTP"
	vpc_id = "vpc-4c6da235"
	health_check {
	    port = 80
	    healthy_threshold = 2
	    unhealthy_threshold = 2
	    timeout = 3
	    protocol = "HTTP"
	    path = "/index.php"
	    interval = 5

	}

}


resource "aws_lb" "alb" {
	name = "Custom-Terraform-elb"
	load_balancer_type = "application"
	internal = "false"
	security_groups = ["sg-0f9bfd348cddf5474"]
	subnets = ["subnet-2d717a65", "subnet-ace6deca", "subnet-5d2d6807"]

}



resource "aws_lb_listener" "alb_listener"{
	load_balancer_arn = aws_lb.alb.arn
	port = 80
	protocol = "HTTP"
	
	default_action {
	    type = "forward"
	    target_group_arn = aws_alb_target_group.tg.arn
	
	}
}

resource "aws_launch_configuration" "config" {
	name = "Custom-Terraform-lc"
	image_id = "ami-3dba8e4e"
	instance_type = "t2.micro"
	security_groups = ["sg-0f9bfd348cddf5474"]
	key_name = "ivan-keypair"
}

resource "aws_autoscaling_group" "asg" {
	name = "Custom-Terraform-asg"
	max_size = 10
	min_size = 2
	health_check_grace_period = 20
	health_check_type = "ELB"
	availability_zones = ["eu-west-1b", "eu-west-1a"]
	desired_capacity = "3"
	force_delete = true
	launch_configuration = aws_launch_configuration.config.name

}


resource "aws_autoscaling_attachment" "attachment" {
	autoscaling_group_name = aws_autoscaling_group.asg.name
	alb_target_group_arn = aws_alb_target_group.tg.arn
}



