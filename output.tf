output "cluster_id" {
  value = aws_eks_cluster.senthil6005.id
}

output "node_group_id" {
  value = aws_eks_node_group.senthil6005.id
}

output "vpc_id" {
  value = aws_vpc.senthil6005_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.senthil6005_subnet[*].id
}
