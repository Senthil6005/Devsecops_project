provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "senthil6005_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "senthil6005-vpc"
  }
}

resource "aws_subnet" "senthil6005_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.senthil6005_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.senthil6005_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "senthil6005-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "senthil6005_igw" {
  vpc_id = aws_vpc.senthil6005_vpc.id

  tags = {
    Name = "senthil6005-igw"
  }
}

resource "aws_route_table" "senthil6005_route_table" {
  vpc_id = aws_vpc.senthil6005_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.senthil6005_igw.id
  }

  tags = {
    Name = "senthil6005-route-table"
  }
}

resource "aws_route_table_association" "senthil6005_association" {
  count          = 2
  subnet_id      = aws_subnet.senthil6005_subnet[count.index].id
  route_table_id = aws_route_table.senthil6005_route_table.id
}

resource "aws_security_group" "senthil6005_cluster_sg" {
  vpc_id = aws_vpc.senthil6005_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "senthil6005-cluster-sg"
  }
}

resource "aws_security_group" "senthil6005_node_sg" {
  vpc_id = aws_vpc.senthil6005_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "senthil6005-node-sg"
  }
}

resource "aws_eks_cluster" "senthil6005" {
  name     = "senthil6005-cluster"
  role_arn = aws_iam_role.senthil6005_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.senthil6005_subnet[*].id
    security_group_ids = [aws_security_group.senthil6005_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.senthil6005_cluster_role_policy
  ]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.senthil6005.name
  addon_name   = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.senthil6005
  ]
}

resource "aws_eks_node_group" "senthil6005" {
  cluster_name    = aws_eks_cluster.senthil6005.name
  node_group_name = "senthil6005-node-group"
  node_role_arn   = aws_iam_role.senthil6005_node_group_role.arn
  subnet_ids      = aws_subnet.senthil6005_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["m7i-flex.large"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.senthil6005_node_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.senthil6005_node_group_role_policy,
    aws_iam_role_policy_attachment.senthil6005_node_group_cni_policy,
    aws_iam_role_policy_attachment.senthil6005_node_group_registry_policy,
    aws_iam_role_policy_attachment.senthil6005_node_group_ebs_policy
  ]
}

resource "aws_iam_role" "senthil6005_cluster_role" {
  name = "senthil6005-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "senthil6005_cluster_role_policy" {
  role       = aws_iam_role.senthil6005_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "senthil6005_node_group_role" {
  name = "senthil6005-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "senthil6005_node_group_role_policy" {
  role       = aws_iam_role.senthil6005_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "senthil6005_node_group_cni_policy" {
  role       = aws_iam_role.senthil6005_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "senthil6005_node_group_registry_policy" {
  role       = aws_iam_role.senthil6005_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "senthil6005_node_group_ebs_policy" {
  role       = aws_iam_role.senthil6005_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
