# outputs
output "ami_id" {
  value = data.aws_ami.example.id
}

output "public_ips" {
  value = { for k, v in aws_instance.k8s_nodes : k => v.public_ip }
}

output "records" {
  value = { for k, v in aws_route53_record.www : k => v.fqdn }
}