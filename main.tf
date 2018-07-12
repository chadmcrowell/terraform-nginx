# Set the default region and the profile to use with access keys
provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

# Grab the availability zones in this region and save it for later use
data "aws_availability_zones" "available" {}

# Create new Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

# Give the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.internet-gateway.id}"
}

# Create new VPC
resource "aws_vpc" "vpc" {
  cidr_block = "172.31.0.0/16"
  tags {
    Name = "default-vpc"
  }
}

# Create a new Subnet 
resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "172.31.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "public-df"
  }
}

# Create new Route Table
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
        cidr_block = "0.0.0.0/0"
	gateway_id = "${aws_internet_gateway.internet-gateway.id}"
	}
  tags {
    Name = "public-df"
  }
}

# Create New Security Group
resource "aws_security_group" "default" {
  name = "sg_public"
  description = "Used for public and private instances for load balancer access"
  vpc_id = "${aws_vpc.vpc.id}"

  #SSH 
  ingress {
    from_port 	= 22
    to_port 	= 22
    protocol 	= "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP 
  ingress {
    from_port 	= 80
    to_port 	= 80
    protocol 	= "tcp"
    cidr_blocks	= ["0.0.0.0/0"]
  }

  #Outbound internet access
  egress {
    from_port	= 0
    to_port 	= 0
    protocol	= "-1"
    cidr_blocks	= ["0.0.0.0/0"]
  }
}

# Creat new key pair to SSH into EC2 Instance
resource "aws_key_pair" "id_rsa" {
    key_name = "id_rsa"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCp7Q8/vAwgI3IIwGezlLmAwTn40oqLb7aZMGRpBz5+HVBSefj0/EWyz4jOp1ckpYxc/ptmUCKIUhLNsCTTW22s8FNqBfvibmPdQ7rRV4mkOFS6d5jXx/VoFldzfu8zdcymvqOv2cmNvvOWv2bavX+SbviKnUPilIVF7pQ41KErj79WsDBJ8iPbS8CNZjaTilF+qBE0et8+fvogNQh/GprXHAc4+fmm1bB+bexbjpOsptNjEPQRCT3UVTzEGD9a/tYYWjwfH7iaiCGKyK0NIMifiCCbnyxzZvsYmvq7wO+j7jcKrBmJydSqf2/ww99ouQeD7WjSOPY8ne4F7E4I1zhj chadcrowell@Chads-MacBook-Pro.local"
}



# Create new EC2 Instance from AMI
resource "aws_instance" "webserver" {
    ami = "ami-0279b47f"
    instance_type = "t2.micro"

    key_name = "${aws_key_pair.id_rsa.id}"
    vpc_security_group_ids = ["${aws_security_group.default.id}"]

    private_ip = "172.31.1.137"

    # We're going to launch into the public subnet for this.
    # Normally, in production environments, webservers would be in
    # private subnets.
    subnet_id = "${aws_subnet.public.id}"
    

    # The connection block tells our provisioner how to
    # communicate with the instance
    connection {
        user = "ec2-user"
    }
}

# Assign Elastic IP to Instance "webserver"
resource "aws_eip" "bar" {
  vpc = true

  instance                  = "${aws_instance.webserver.id}"
  associate_with_private_ip = "172.31.1.137"
  depends_on                = ["aws_internet_gateway.internet-gateway"]
}

