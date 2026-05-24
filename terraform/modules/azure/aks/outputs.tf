output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.this.id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
