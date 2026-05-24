output "security_group_id" {
  description = "Security group injected by the baseline"
  value       = aws_security_group.baseline_sg.id
}

output "iam_policy_arn" {
  description = "IAM policy ARN enforcing security guardrails"
  value       = aws_iam_policy.security_baseline.arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail audit trail"
  value       = aws_cloudtrail.audit_trail.arn
}
