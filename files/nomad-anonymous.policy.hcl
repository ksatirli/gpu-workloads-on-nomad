# Anonymous policy for unauthenticated requests (e.g. web UI without token)
# Apply after bootstrap: nomad acl policy apply -description "Anonymous read-only" anonymous nomad-anonymous.policy.hcl
# see https://developer.hashicorp.com/nomad/docs/secure/acl/bootstrap

namespace "default" {
  policy       = "read"
  capabilities = ["list-jobs", "read-job"]
}

# Required for /v1/regions and other operator APIs used by the web UI
agent {
  policy = "read"
}

operator {
  policy = "read"
}

quota {
  policy = "read"
}

node {
  policy = "read"
}

host_volume "*" {
  policy = "read"
}
