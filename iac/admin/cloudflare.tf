locals {
  zone_name = data.cloudflare_zone.zone.name
  zone_id   = data.cloudflare_zone.zone.zone_id

  # A records with identical config
  a_records = toset([
    local.zone_name,
    "www.${local.zone_name}",
  ])

  # CNAMEs with identical config (all proxied)
  cnames = {
    "notes.${local.zone_name}" = "publish-main.obsidian.md"
    "tilde.${local.zone_name}" = "tilde.club"
    "web.${local.zone_name}"   = "celia-vytrac.github.io"
  }

  dkims = {
    "sig1._domainkey.${local.zone_name}" = "sig1.dkim.${local.zone_name}.at.icloudmailadmin.com"
  }

  spf_includes = [
    "icloud.com",
  ]
  spf_txt = trimspace(
    <<-EOT
      v=spf1 ${join(" ", [for s in local.spf_includes : "include:${s}"])} ~all
    EOT
  )

  # data comes in from secret manager as a list of string separated by newlines
  gcloud_domain_verifications = [
    for line in split(
      "\n",
      data.google_secret_manager_secret_version.gcloud_domain_verifications.secret_data
    )
    : chomp(line)
  ]
  github_domain_verifications = [
    for line in split(
      "\n",
      data.google_secret_manager_secret_version.github_domain_verifications.secret_data
    )
    : chomp(line)
  ]
  icloud_domain_verifications = [
    for line in split(
      "\n",
      data.google_secret_manager_secret_version.icloud_domain_verifications.secret_data
    )
    : chomp(line)
  ]
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = local.zone_id
  type    = "TXT"
  ttl     = 3600

  name = "_dmarc.${local.zone_name}"

  content = "v=DMARC1; p=none; rua=mailto:dmarc@${local.zone_name}"
}

resource "cloudflare_dns_record" "spf" {
  zone_id = local.zone_id
  name    = local.zone_name
  type    = "TXT"
  ttl     = 3600

  content = local.spf_txt
}

resource "cloudflare_dns_record" "mx_icloud" {
  count = 2

  zone_id  = local.zone_id
  name     = local.zone_name
  type     = "MX"
  priority = 10
  ttl      = 3600

  content = format(
    "mx%02d.mail.icloud.com",
    count.index + 1
  )
}

#
# DNS Verifications for proving domain ownership
# count is used here instead of for_each because
# local.gcloud_domain_verifications is sensitive=true
#
resource "cloudflare_dns_record" "gcloud_verifications" {
  count   = length(local.gcloud_domain_verifications)
  zone_id = local.zone_id
  name    = local.zone_name
  ttl     = 3600
  type    = "TXT"

  content = "google-site-verification=${local.gcloud_domain_verifications[count.index]}"
}

#
# DNS Verifications for proving domain ownership
# count is used here instead of for_each because
# local.github_domain_verifications is sensitive=true
#
resource "cloudflare_dns_record" "github_verifications" {
  count   = length(local.github_domain_verifications)
  zone_id = local.zone_id
  name    = "_github-pages-challenge-celia-vytrac.web.${local.zone_name}"
  ttl     = 3600
  type    = "TXT"

  content = local.github_domain_verifications[count.index]
}

#
# DNS Verifications for proving domain ownership
# count is used here instead of for_each because
# local.icloud_domain_verifications is sensitive=true
#
resource "cloudflare_dns_record" "icloud_verifications" {
  count   = length(local.icloud_domain_verifications)
  zone_id = local.zone_id
  name    = local.zone_name
  ttl     = 3600
  type    = "TXT"

  content = "apple-domain=${local.icloud_domain_verifications[count.index]}"
}

#
# www redirect
#
resource "cloudflare_ruleset" "www" {
  zone_id = local.zone_id
  name    = "redirects"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [
    {
      enabled     = true
      description = "Redirect www"
      expression = format(
        "(http.host eq \"www.%s\")",
        local.zone_name
      )
      action = "redirect"

      action_parameters = {
        from_value = {
          status_code           = 302
          preserve_query_string = true
          target_url = {
            expression = format(
              "concat(\"https://%s\", http.request.uri.path)",
              local.zone_name
            )
          }
        }
      }
    }
  ]
}

#
# A Records
#
resource "cloudflare_dns_record" "a_records" {
  for_each = local.a_records

  zone_id = local.zone_id
  name    = each.value
  type    = "A"
  content = "192.0.2.1"
  proxied = true
  ttl     = 1
}

#
# CNAMEs
#
resource "cloudflare_dns_record" "cnames" {
  for_each = local.cnames

  zone_id = local.zone_id
  name    = each.key
  type    = "CNAME"
  content = each.value
  proxied = true
  ttl     = 1
}

#
# DKIMs
#
resource "cloudflare_dns_record" "dkims" {
  for_each = local.dkims

  zone_id = local.zone_id
  name    = each.key
  type    = "CNAME"
  content = each.value
  ttl     = 3600
}
