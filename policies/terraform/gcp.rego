package terraform.gcp

# ── GKE Cluster ───────────────────────────────────────────────────────────────

# deletion_protection = false risks accidental cluster deletion
warn[msg] {
	input.resource.google_container_cluster[name].deletion_protection == false
	msg := sprintf(
		"google_container_cluster.%s: deletion_protection is false – set to true in production environments",
		[name],
	)
}

# private_cluster_config is an HCL block – parsed as an object by the HCL2 parser
deny[msg] {
	pcc := input.resource.google_container_cluster[name].private_cluster_config
	is_object(pcc)
	not pcc.enable_private_nodes
	msg := sprintf("google_container_cluster.%s: private_cluster_config.enable_private_nodes must be true", [name])
}

deny[msg] {
	cluster := input.resource.google_container_cluster[name]
	not cluster.enable_shielded_nodes
	msg := sprintf("google_container_cluster.%s: enable_shielded_nodes must be true", [name])
}

# network_policy is an HCL block – parsed as an object
deny[msg] {
	np := input.resource.google_container_cluster[name].network_policy
	is_object(np)
	not np.enabled
	msg := sprintf("google_container_cluster.%s: network_policy.enabled must be true", [name])
}

deny[msg] {
	cluster := input.resource.google_container_cluster[name]
	not cluster.network_policy
	msg := sprintf("google_container_cluster.%s: a network_policy block must be defined with enabled = true", [name])
}

# workload_identity_config is an HCL block – parsed as an object
deny[msg] {
	cluster := input.resource.google_container_cluster[name]
	not cluster.workload_identity_config
	msg := sprintf("google_container_cluster.%s: workload_identity_config block must be present", [name])
}

# ── GKE Node Pool ─────────────────────────────────────────────────────────────

# node_config is an HCL block; shielded_instance_config is a nested block – both parsed as objects
deny[msg] {
	nc := input.resource.google_container_node_pool[name].node_config
	is_object(nc)
	sic := nc.shielded_instance_config
	is_object(sic)
	not sic.enable_secure_boot
	msg := sprintf("google_container_node_pool.%s: node_config.shielded_instance_config.enable_secure_boot must be true", [name])
}

deny[msg] {
	nc := input.resource.google_container_node_pool[name].node_config
	is_object(nc)
	sic := nc.shielded_instance_config
	is_object(sic)
	not sic.enable_integrity_monitoring
	msg := sprintf("google_container_node_pool.%s: node_config.shielded_instance_config.enable_integrity_monitoring must be true", [name])
}

# management is an HCL block – parsed as an object
deny[msg] {
	mgmt := input.resource.google_container_node_pool[name].management
	is_object(mgmt)
	not mgmt.auto_repair
	msg := sprintf("google_container_node_pool.%s: management.auto_repair must be true", [name])
}

deny[msg] {
	mgmt := input.resource.google_container_node_pool[name].management
	is_object(mgmt)
	not mgmt.auto_upgrade
	msg := sprintf("google_container_node_pool.%s: management.auto_upgrade must be true", [name])
}

# ── GCS Bucket ────────────────────────────────────────────────────────────────

deny[msg] {
	bucket := input.resource.google_storage_bucket[name]
	not bucket.uniform_bucket_level_access
	msg := sprintf("google_storage_bucket.%s: uniform_bucket_level_access must be true", [name])
}

# public_access_prevention defaults to "inherited" which may allow public access
warn[msg] {
	bucket := input.resource.google_storage_bucket[name]
	not bucket.public_access_prevention
	msg := sprintf(
		"google_storage_bucket.%s: public_access_prevention should be set to 'enforced'",
		[name],
	)
}

deny[msg] {
	bucket := input.resource.google_storage_bucket[name]
	bucket.public_access_prevention
	bucket.public_access_prevention != "enforced"
	msg := sprintf(
		"google_storage_bucket.%s: public_access_prevention must be 'enforced' (got '%s')",
		[name, bucket.public_access_prevention],
	)
}

# versioning is an HCL block – parsed as an object
warn[msg] {
	bucket := input.resource.google_storage_bucket[name]
	not bucket.versioning
	msg := sprintf("google_storage_bucket.%s: versioning block should be present with enabled = true", [name])
}

deny[msg] {
	ver := input.resource.google_storage_bucket[name].versioning
	is_object(ver)
	not ver.enabled
	msg := sprintf("google_storage_bucket.%s: versioning.enabled must be true", [name])
}
