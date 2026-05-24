output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Private endpoint of the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}
