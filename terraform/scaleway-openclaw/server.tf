resource "scaleway_instance_ip" "openclaw_ip" {
  project_id = var.project_id
}

resource "scaleway_instance_security_group" "openclaw_sg" {
  project_id              = var.project_id
  name                    = "${var.instance_name}-sg"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action = "accept"
    port   = 22
  }

  inbound_rule {
    action = "accept"
    port   = 80
  }

  inbound_rule {
    action = "accept"
    port   = 443
  }
}

resource "scaleway_instance_server" "openclaw_server" {
  project_id = var.project_id
  type       = var.instance_type
  image      = var.image
  name       = var.instance_name

  tags = ["openclaw", "node"]

  ip_id = scaleway_instance_ip.openclaw_ip.id

  root_volume {
    delete_on_termination = true
    size_in_gb            = 20
  }

  security_group_id = scaleway_instance_security_group.openclaw_sg.id
}
