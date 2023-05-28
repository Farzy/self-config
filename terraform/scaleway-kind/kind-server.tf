resource "scaleway_instance_ip" "kind-ip" {
}

resource "scaleway_instance_security_group" "kind-sg" {
  name                    = "kind"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    port     = "22"
    ip_range = "0.0.0.0/0"
  }
}

resource "scaleway_instance_server" "kind-server" {
  type  = "DEV1-L"
  image = "debian_bullseye"
  name  = "kind-server"

  tags = ["docker", "kubernetes"]

  ip_id = scaleway_instance_ip.kind-ip.id

  #  additional_volume_ids = [scaleway_instance_volume.data.id]

  root_volume {
    delete_on_termination = true
    # The local storage of a DEV1-L instance is 80 GB, subtract 30 GB from the additional l_ssd volume, then the root volume needs to be 50 GB.
    size_in_gb = 30
  }

  security_group_id = scaleway_instance_security_group.kind-sg.id
}

resource "scaleway_instance_user_data" "kind-user-data" {
  server_id = scaleway_instance_server.kind-server.id
  key       = "cloud-init"
  value     = <<-EOF
#!/bin/bash
apt update
apt upgrade -y
EOF
}
