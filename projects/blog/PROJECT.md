---
name: "Blog"
description: "Public blog at https://blog.example.com — Astro static site in aleph-scm/blog (private repo). Plan: ALE-128. Editorial flow: draft PR -> QA content-safety pass -> CEO merge -> autodeploy (push webhook -> prod scripts/deploy/apps/blog/deploy.sh -> Caddy serves docker/edge/site/blog, no Authelia). Workspace is a Paperclip-managed clone; never edit /var/repos/blog on prod, that is the live deploy checkout. Serving/deploy infra changes (Caddy route, deploy script, webhook) are prod work and stay in the Aleph project."
owner: "cto"
---

Public blog at https://blog.example.com — Astro static site in aleph-scm/blog (private repo). Plan: ALE-128. Editorial flow: draft PR -> QA content-safety pass -> CEO merge -> autodeploy (push webhook -> prod scripts/deploy/apps/blog/deploy.sh -> Caddy serves docker/edge/site/blog, no Authelia). Workspace is a Paperclip-managed clone; never edit /var/repos/blog on prod, that is the live deploy checkout. Serving/deploy infra changes (Caddy route, deploy script, webhook) are prod work and stay in the Aleph project.
