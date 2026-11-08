#configuring the provider

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# Create an EC2 instance in the public subnet

resource "aws_instance" "three_tier_ec2_main" {
  ami                         = "ami-0dd60a46ecc6eac16"
  instance_type               = "t8i.small"
  subnet_id                   = aws_subnet.public_subnet1.id
  availability_zone           = "ap-southeast-2a"
  key_name                    = aws_key_pair.datacenter_kp.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id, aws_security_group.ssh.id
  ]

  # User data script to install and configure the Flask application
  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y python3 python3-pip python3-venv

mkdir -p /opt/infra-app
cd /opt/infra-app

python3 -m venv venv
venv/bin/pip install flask gunicorn

cat > app.py <<'PY'
from flask import Flask, jsonify
import time

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "application": "InfraWatch",
        "server": "EC2-Server-1",
        "status": "running"
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/api/products")
def products():
    return jsonify([
        {"id": 1, "name": "Laptop"},
        {"id": 2, "name": "Monitor"},
        {"id": 3, "name": "Keyboard"}
    ])

@app.route("/api/slow")
def slow():
    time.sleep(5)
    return jsonify({"message": "Slow response completed"})

@app.route("/api/heavy")
def heavy():
    result = sum(i * i for i in range(10_000_000))
    return jsonify({"result": result})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

cat > /etc/systemd/system/infra-app.service <<'SERVICE'
[Unit]
Description=InfraWatch Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt/infra-app
ExecStart=/opt/infra-app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:80 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable infra-app
systemctl start infra-app
EOF
  tags = {
    Name = "three_tier_ec2_main_public"
  }
}

# Create a second EC2 instance in the public subnet
#(loadbalncer sends the traffic to these instances)

resource "aws_instance" "three_tier_ec2_main2" {
  ami                         = "ami-0dd60a46ecc6eac16"
  instance_type               = "t8i.small"
  subnet_id                   = aws_subnet.public_subnet2.id
  availability_zone           = "ap-southeast-2b"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.datacenter_kp.key_name
  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id, aws_security_group.ssh.id
  ]
  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y python3 python3-pip python3-venv

mkdir -p /opt/infra-app
cd /opt/infra-app

python3 -m venv venv
venv/bin/pip install flask gunicorn

cat > app.py <<'PY'
from flask import Flask, jsonify
import time

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "application": "InfraWatch",
        "server": "EC2-Server-2",
        "status": "running"
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/api/products")
def products():
    return jsonify([
        {"id": 1, "name": "Laptop"},
        {"id": 2, "name": "Monitor"},
        {"id": 3, "name": "Keyboard"}
    ])

@app.route("/api/slow")
def slow():
    time.sleep(5)
    return jsonify({"message": "Slow response completed"})

@app.route("/api/heavy")
def heavy():
    result = sum(i * i for i in range(10_000_000))
    return jsonify({"result": result})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

cat > /etc/systemd/system/infra-app.service <<'SERVICE'
[Unit]
Description=InfraWatch Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt/infra-app
ExecStart=/opt/infra-app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:80 app:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable infra-app
systemctl start infra-app
EOF
  tags = {
    Name = "three_tier_ec2_main_public2"
  }
}


# Create the key pair
resource "tls_private_key" "datacenter_kp" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "datacenter_kp" {
  key_name   = "datacenter-kp"
  public_key = tls_private_key.datacenter_kp.public_key_openssh
}
# Save the private key to file
resource "local_file" "private_key" {
  content         = tls_private_key.datacenter_kp.private_key_pem
  filename        = "/home/lenovo/downloads/datacenter-kp.pem"
  file_permission = "0400"
}

# Output the key pair name (optional)
output "key_pair_name" {
  value = aws_key_pair.datacenter_kp.key_name
}


resource "aws_vpc" "three_tier_vpc" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_subnet" "public_subnet1" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "three_public_sb1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2b"

  tags = {
    Name = "three_public_subnet2"
  }
}


resource "aws_internet_gateway" "three_tier_igw" {
  vpc_id = aws_vpc.three_tier_vpc.id
}

resource "aws_route_table" "three_tier_public_rt" {
  vpc_id = aws_vpc.three_tier_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.three_tier_igw.id
  }
}

#route table association for public subnets

resource "aws_route_table_association" "public_subnet1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.three_tier_public_rt.id
}

resource "aws_route_table_association" "public_subnet2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.three_tier_public_rt.id
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.three_tier_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
## security group for the EC2 instances to allow HTTP traffic from the ALB only

resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.three_tier_vpc.id

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
}


resource "aws_security_group" "ec2_sg" {
  name        = "application-ec2-sg"
  description = "Allow HTTP only from ALB"
  vpc_id      = aws_vpc.three_tier_vpc.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh" {
  name        = "ssh_sg"
  description = "Security group for SSH access"
  vpc_id      = aws_vpc.three_tier_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "three_tier_lb" {
  name               = "three-tier-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "application-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.three_tier_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}


resource "aws_lb_target_group_attachment" "ec2_1" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.three_tier_ec2_main.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.three_tier_ec2_main2.id
  port             = 80
}
