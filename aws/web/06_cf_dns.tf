# cf_dns.tf
# ########################################
# Cloudflare
# ########################################
resource "cloudflare_record" "dns_record" {
  zone_id = var.cloudflare_zone_id
  name    = local.dns_record
  content = aws_cloudfront_distribution.web.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
