resource "aws_vpc" "vpc_london" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-london"
  }

}

output "vpc_london" {
  value = aws_vpc.vpc_london.id
}

#Create subnet # 1 in eu-west-2
resource "aws_subnet" "subnet_1" {
  availability_zone = "eu-west-2a"
  vpc_id            = aws_vpc.vpc_london.id
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name = "subnet_1"
  }
}

#Create public subnet # 1 in eu-west-2
resource "aws_subnet" "pub-subnet_1" {
  availability_zone       = "eu-west-2a"
  vpc_id                  = aws_vpc.vpc_london.id
  cidr_block              = "10.0.100.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "pub-subnet_1"
  }

}


#Create subnet #2  in eu-west-2
resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.vpc_london.id
  availability_zone = "eu-west-2b"
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "subnet_2"
  }

}

#Create subnet #2  in eu-west-2
resource "aws_subnet" "pub-subnet_2" {
  vpc_id                  = aws_vpc.vpc_london.id
  availability_zone       = "eu-west-2b"
  cidr_block              = "10.0.200.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "pub-subnet_2"
  }

}

#Create IGW in eu-west-2
resource "aws_internet_gateway" "london-igw" {
  vpc_id = aws_vpc.vpc_london.id
  tags = {
    Name = "london-igw"
  }
}

resource "aws_route_table" "pub-subnet-RT" {
  vpc_id = aws_vpc.vpc_london.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.london-igw.id
  }

  tags = {
    Name = "pub-subnet-RT"
  }
}

resource "aws_route_table" "priv-subnet-RT" {
  vpc_id = aws_vpc.vpc_london.id

  tags = {
    Name = "priv-subnet-RT"
  }
}

resource "aws_route_table_association" "pub-subnet1-RTA" {
  subnet_id      = aws_subnet.pub-subnet_1.id
  route_table_id = aws_route_table.pub-subnet-RT.id
}

resource "aws_route_table_association" "pub-subnet2-RTA" {
  subnet_id      = aws_subnet.pub-subnet_2.id
  route_table_id = aws_route_table.pub-subnet-RT.id
}

resource "aws_route_table_association" "subnet2-RTA" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.priv-subnet-RT.id
}

resource "aws_route_table_association" "subnet1-RTA" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.priv-subnet-RT.id
}

resource "aws_instance" "inst-subnet_1" {
  ami           = "ami-00785f4835c6acf64"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_1.id
  tags = {
    Name = "inst-subnet_1"
  }
}

resource "aws_instance" "inst-pub-subnet_1" {
  ami           = "ami-00785f4835c6acf64"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.pub-subnet_1.id
  vpc_security_group_ids = [aws_security_group.pub-instance-sg.id]
  associate_public_ip_address = true
  user_data = <<- EOF
                #!/bin/bash
                echo "<H1>Welcome to GPIS Consulting</H1>"
                > index.html
                EOF
  user_data_replace_on_change = true
  tags = {
    Name = "inst-pub-subnet_1"
  }
}

resource "aws_instance" "inst-pub-subnet_2" {
  ami           = "ami-00785f4835c6acf64"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.pub-subnet_2.id
  vpc_security_group_ids = [aws_security_group.pub-instance-sg.id]
  associate_public_ip_address = true
  user_data = <<- EOF
                #!/bin/bash
		echo "<H1>Welcome to GPIS Consulting</H1>"
		> index.html
		EOF
  user_data_replace_on_change = true
  tags = {
    Name = "inst-pub-subnet_2"
  }
}

resource "aws_instance" "inst-subnet_2" {
  ami           = "ami-00785f4835c6acf64"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_2.id
  tags = {
    Name = "inst-subnet_2"
  }
}

resource "aws_security_group "pub-instance-sg" {
  name = "pub-instance-sg"
  vpc_id = aws_vpc.vpc_london.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = tcp
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = tcp
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
