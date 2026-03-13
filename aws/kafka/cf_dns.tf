# cf_dns.tf
# ########################################
# Cloudflare
# ########################################
resource "cloudflare_record" "dns_record" {
  zone_id = var.cloudflare_zone_id
  name    = local.dns_record
  # content = aws_cloudfront_distribution.cdn.domain_name
  content = aws_lb.alb.dns_name
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
