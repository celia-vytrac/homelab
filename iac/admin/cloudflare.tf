#
# Email
#
resource "cloudflare_email_routing_address" "email" {
  account_id = local.cloudflare_account_id
  email      = local.personal_email
}

resource "cloudflare_email_routing_rule" "email" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "celia"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "celia@${data.cloudflare_zone.zone.name}"
  }

  action {
    type  = "forward"
    value = [local.personal_email]
  }
}

resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "_dmarc"
  type    = "TXT"

  value = "v=DMARC1;  p=none; rua=mailto:8d277764549d4f5a8fb5d920925f6691@dmarc-reports.cloudflare.net"
}

resource "cloudflare_record" "spf" {
  zone_id = data.cloudflare_zone.zone.id
  name    = data.cloudflare_zone.zone.name
  type    = "TXT"

  value = "v=spf1 include:_spf.mx.cloudflare.net include:_spf.google.com ~all"
}

resource "cloudflare_record" "mail" {
  for_each = { for i, priority in local.mx_priorities : i => priority }
  zone_id  = data.cloudflare_zone.zone.id
  name     = data.cloudflare_zone.zone.name
  priority = each.value
  type     = "MX"

  value = "route${each.key + 1}.mx.cloudflare.net"
}

#
# DNS Verifications for proving domain ownership
# count is used here instead of for_each because
# local.gcloud_domain_verifications is sensitive=true
#
resource "cloudflare_record" "gcloud_verifications" {
  count   = 2
  zone_id = data.cloudflare_zone.zone.id
  name    = data.cloudflare_zone.zone.name
  ttl     = 3600
  type    = "TXT"

  value = "google-site-verification=${local.gcloud_domain_verifications[count.index]}"
}

#
# www redirect
#
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "www"
  proxied = true
  type    = "A"

  value = "192.0.2.1"
}

resource "cloudflare_page_rule" "www" {
  zone_id  = data.cloudflare_zone.zone.id
  target   = "www.${data.cloudflare_zone.zone.name}/*"
  priority = 1

  actions {
    forwarding_url {
      url         = "https://${data.cloudflare_zone.zone.name}/$1"
      status_code = 302
    }
  }
}

#
# root self resolve
#
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.zone.id
  name    = data.cloudflare_zone.zone.name
  proxied = true
  type    = "A"

  value = "192.0.2.1"
}

#
# tilde.club redirect
#
resource "cloudflare_record" "tilde" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "tilde"
  proxied = true
  type    = "CNAME"

  value = "tilde.club"
}

#
# obsidian publish
#
resource "cloudflare_record" "notes" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "notes"
  proxied = true
  type    = "CNAME"

  value = "publish-main.obsidian.md"
}
