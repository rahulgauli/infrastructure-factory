package terraform.aws

# ── EC2 ──────────────────────────────────────────────────────────────────────

deny[msg] {
	input.resource.aws_instance[name].associate_public_ip_address == true
	msg := sprintf("aws_instance.%s: associate_public_ip_address must be false", [name])
}

deny[msg] {
	instance := input.resource.aws_instance[name]
	not instance.monitoring
	msg := sprintf("aws_instance.%s: monitoring must be enabled (set monitoring = true)", [name])
}

deny[msg] {
	instance := input.resource.aws_instance[name]
	not instance.ebs_optimized
	msg := sprintf("aws_instance.%s: ebs_optimized must be true", [name])
}

# root_block_device is an HCL block – parsed as an object by the HCL2 parser (single occurrence)
deny[msg] {
	rbd := input.resource.aws_instance[name].root_block_device
	is_object(rbd)
	not rbd.encrypted
	msg := sprintf("aws_instance.%s: root_block_device must have encrypted = true", [name])
}

# ── RDS ──────────────────────────────────────────────────────────────────────

deny[msg] {
	input.resource.aws_db_instance[name].publicly_accessible == true
	msg := sprintf("aws_db_instance.%s: publicly_accessible must be false", [name])
}

deny[msg] {
	db := input.resource.aws_db_instance[name]
	not db.storage_encrypted
	msg := sprintf("aws_db_instance.%s: storage_encrypted must be true", [name])
}

deny[msg] {
	db := input.resource.aws_db_instance[name]
	not db.deletion_protection
	msg := sprintf("aws_db_instance.%s: deletion_protection must be true", [name])
}

deny[msg] {
	db := input.resource.aws_db_instance[name]
	not db.backup_retention_period
	msg := sprintf("aws_db_instance.%s: backup_retention_period must be set (minimum 7 days)", [name])
}

deny[msg] {
	db := input.resource.aws_db_instance[name]
	db.backup_retention_period < 7
	msg := sprintf("aws_db_instance.%s: backup_retention_period must be >= 7 days (got %d)", [name, db.backup_retention_period])
}

# ── EKS ──────────────────────────────────────────────────────────────────────

# vpc_config is an HCL block – parsed as an object by the HCL2 parser
deny[msg] {
	vpc := input.resource.aws_eks_cluster[name].vpc_config
	is_object(vpc)
	vpc.endpoint_public_access == true
	msg := sprintf("aws_eks_cluster.%s: vpc_config.endpoint_public_access must be false", [name])
}

deny[msg] {
	cluster := input.resource.aws_eks_cluster[name]
	not cluster.enabled_cluster_log_types
	msg := sprintf("aws_eks_cluster.%s: enabled_cluster_log_types must be set", [name])
}

deny[msg] {
	cluster := input.resource.aws_eks_cluster[name]
	cluster.enabled_cluster_log_types
	count(cluster.enabled_cluster_log_types) == 0
	msg := sprintf("aws_eks_cluster.%s: enabled_cluster_log_types must not be empty", [name])
}

# ── Security Groups ──────────────────────────────────────────────────────────

# Single ingress block (object): applies when there is exactly one ingress block
deny[msg] {
	sg := input.resource.aws_security_group[sg_name]
	is_object(sg.ingress)
	sg.ingress.cidr_blocks[_] == "0.0.0.0/0"
	msg := sprintf(
		"aws_security_group.%s: ingress allows traffic from 0.0.0.0/0 on port %d – use a restricted CIDR instead",
		[sg_name, sg.ingress.from_port],
	)
}

# Multiple ingress blocks (array): applies when there are multiple ingress blocks
deny[msg] {
	sg := input.resource.aws_security_group[sg_name]
	is_array(sg.ingress)
	ingress := sg.ingress[_]
	ingress.cidr_blocks[_] == "0.0.0.0/0"
	msg := sprintf(
		"aws_security_group.%s: ingress allows traffic from 0.0.0.0/0 on port %d – use a restricted CIDR instead",
		[sg_name, ingress.from_port],
	)
}

deny[msg] {
	sg := input.resource.aws_security_group[sg_name]
	is_object(sg.ingress)
	sg.ingress.ipv6_cidr_blocks[_] == "::/0"
	msg := sprintf(
		"aws_security_group.%s: ingress allows traffic from ::/0 on port %d – use a restricted CIDR instead",
		[sg_name, sg.ingress.from_port],
	)
}

deny[msg] {
	sg := input.resource.aws_security_group[sg_name]
	is_array(sg.ingress)
	ingress := sg.ingress[_]
	ingress.ipv6_cidr_blocks[_] == "::/0"
	msg := sprintf(
		"aws_security_group.%s: ingress allows traffic from ::/0 on port %d – use a restricted CIDR instead",
		[sg_name, ingress.from_port],
	)
}

# ── S3 Public Access Block ───────────────────────────────────────────────────

deny[msg] {
	block := input.resource.aws_s3_bucket_public_access_block[name]
	not block.block_public_acls
	msg := sprintf("aws_s3_bucket_public_access_block.%s: block_public_acls must be true", [name])
}

deny[msg] {
	block := input.resource.aws_s3_bucket_public_access_block[name]
	not block.block_public_policy
	msg := sprintf("aws_s3_bucket_public_access_block.%s: block_public_policy must be true", [name])
}

deny[msg] {
	block := input.resource.aws_s3_bucket_public_access_block[name]
	not block.restrict_public_buckets
	msg := sprintf("aws_s3_bucket_public_access_block.%s: restrict_public_buckets must be true", [name])
}

# Every aws_s3_bucket must have a corresponding aws_s3_bucket_public_access_block in the same file.
# Count-based check to handle multiple buckets: each bucket must have exactly one access block.
deny[msg] {
	bucket_names := {k | input.resource.aws_s3_bucket[k]}
	pab_names := {k | input.resource.aws_s3_bucket_public_access_block[k]}
	count(bucket_names) > count(pab_names)
	msg := sprintf(
		"Found %d aws_s3_bucket resource(s) but only %d aws_s3_bucket_public_access_block resource(s) – every S3 bucket must have a public access block",
		[count(bucket_names), count(pab_names)],
	)
}

# ── S3 Encryption ────────────────────────────────────────────────────────────

deny[msg] {
	bucket_names := {k | input.resource.aws_s3_bucket[k]}
	enc_names := {k | input.resource.aws_s3_bucket_server_side_encryption_configuration[k]}
	count(bucket_names) > count(enc_names)
	msg := sprintf(
		"Found %d aws_s3_bucket resource(s) but only %d aws_s3_bucket_server_side_encryption_configuration resource(s) – every S3 bucket must have server-side encryption configured",
		[count(bucket_names), count(enc_names)],
	)
}

# ── S3 Versioning ────────────────────────────────────────────────────────────

warn[msg] {
	bucket_names := {k | input.resource.aws_s3_bucket[k]}
	ver_names := {k | input.resource.aws_s3_bucket_versioning[k]}
	count(bucket_names) > count(ver_names)
	msg := sprintf(
		"Found %d aws_s3_bucket resource(s) but only %d aws_s3_bucket_versioning resource(s) – every S3 bucket should have versioning enabled",
		[count(bucket_names), count(ver_names)],
	)
}

# ── SQS ──────────────────────────────────────────────────────────────────────

deny[msg] {
	queue := input.resource.aws_sqs_queue[name]
	not queue.kms_master_key_id
	msg := sprintf("aws_sqs_queue.%s: kms_master_key_id must be set for server-side encryption", [name])
}

warn[msg] {
	queue := input.resource.aws_sqs_queue[name]
	not queue.redrive_policy
	msg := sprintf("aws_sqs_queue.%s: redrive_policy should be configured to route failed messages to a dead-letter queue", [name])
}

# ── CloudTrail ───────────────────────────────────────────────────────────────

deny[msg] {
	trail := input.resource.aws_cloudtrail[name]
	not trail.enable_log_file_validation
	msg := sprintf("aws_cloudtrail.%s: enable_log_file_validation must be true", [name])
}

deny[msg] {
	trail := input.resource.aws_cloudtrail[name]
	not trail.is_multi_region_trail
	msg := sprintf("aws_cloudtrail.%s: is_multi_region_trail must be true", [name])
}
