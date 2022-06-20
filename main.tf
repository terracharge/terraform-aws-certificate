
locals {
  distinct_domain_names = distinct(concat([var.domain_name], [for s in var.subject_alternative_names : replace(s, "*.", "")]))
  validation_domains    = [for k, v in aws_acm_certificate.this.domain_validation_options : tomap(v) if contains(local.distinct_domain_names, replace(v.domain_name, "*.", ""))]
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method
  options {
    certificate_transparency_logging_preference = var.certificate_transparency_logging_preference ? "ENABLED" : "DISABLED"
  }
  tags = var.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  count   = var.validation_method == "DNS" && var.validate_certificate ? length(local.distinct_domain_names) + 1 : 0
  zone_id = var.zone_id
  name    = element(local.validation_domains, count.index)["resource_record_name"]
  type    = element(local.validation_domains, count.index)["resource_record_type"]
  ttl     = var.dns_ttl
  records = [
    element(local.validation_domains, count.index)["resource_record_value"]
  ]
  allow_overwrite = var.validation_allow_overwrite_records
  depends_on      = [aws_acm_certificate.this]
  provider        = aws.dns
}

resource "aws_acm_certificate_validation" "this" {
  count                   = var.validation_method == "DNS" && var.validate_certificate && var.wait_for_validation ? 1 : 0
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = aws_route53_record.validation.*.fqdn
}
