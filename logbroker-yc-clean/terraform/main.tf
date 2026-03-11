provider "yandex" {
  token     = ""
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

locals {
  ssh_public_key = trimspace(file(var.ssh_public_key_path))

  vm_resources_default = {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  backend_names = [for i in range(var.backend_count) : format("logbroker-%02d", i + 1)]
}

# Public images

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

data "yandex_compute_image" "nat" {
  family = "nat-instance-ubuntu"
}

# Network

resource "yandex_vpc_network" "hw2" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "public" {
  name           = var.public_subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.hw2.id
  v4_cidr_blocks = var.public_subnet_cidr
}

resource "yandex_vpc_security_group" "nat" {
  name       = "hw2-nat-sg"
  network_id = yandex_vpc_network.hw2.id

  ingress {
    protocol       = "TCP"
    description    = "SSH from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "ANY"
    description    = "Allow all traffic from private subnet (for NAT forwarding)"
    v4_cidr_blocks = var.private_subnet_cidr
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "nginx" {
  name       = "hw2-nginx-sg"
  network_id = yandex_vpc_network.hw2.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "nat" {
  name        = "hw2-nat"
  hostname    = "hw2-nat"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = local.vm_resources_default.cores
    memory        = local.vm_resources_default.memory
    core_fraction = local.vm_resources_default.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.nat.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nat.id]
  }

  metadata = {
    serial-port-enable = "1"
    user-data          = <<-EOT
#cloud-config
users:
  - name: ${var.ssh_user}
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo]
    ssh_authorized_keys:
      - ${local.ssh_public_key}
EOT
  }
}

resource "yandex_vpc_route_table" "private_via_nat" {
  name       = "hw2-private-via-nat"
  network_id = yandex_vpc_network.hw2.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat.network_interface[0].ip_address
  }
}

resource "yandex_vpc_subnet" "private" {
  name           = var.private_subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.hw2.id
  v4_cidr_blocks = var.private_subnet_cidr
  route_table_id = yandex_vpc_route_table.private_via_nat.id
}

resource "yandex_vpc_security_group" "backend" {
  name       = "hw2-backend-sg"
  network_id = yandex_vpc_network.hw2.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP from public subnet (nginx)"
    v4_cidr_blocks = var.public_subnet_cidr
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH via NAT/jump host"
    v4_cidr_blocks = var.public_subnet_cidr
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "clickhouse" {
  name       = "hw2-clickhouse-sg"
  network_id = yandex_vpc_network.hw2.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP interface from private subnet"
    v4_cidr_blocks = var.private_subnet_cidr
    port           = 8123
  }

  ingress {
    protocol       = "TCP"
    description    = "Native interface from private subnet"
    v4_cidr_blocks = var.private_subnet_cidr
    port           = 9000
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH via NAT/jump host"
    v4_cidr_blocks = var.public_subnet_cidr
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ClickHouse

resource "yandex_compute_instance" "clickhouse" {
  name        = "clickhouse"
  hostname    = "clickhouse"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 30
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.clickhouse.id]
  }

  metadata = {
    serial-port-enable = "1"
    user-data = templatefile("${path.module}/templates/clickhouse-cloud-init.yaml.tftpl", {
      instance_name       = "clickhouse"
      ssh_user            = var.ssh_user
      ssh_public_key      = local.ssh_public_key
      clickhouse_db       = var.clickhouse_db
      clickhouse_table    = var.clickhouse_table
      clickhouse_user     = var.clickhouse_user
      clickhouse_password = var.clickhouse_password
      clickhouse_image_tag = var.clickhouse_image_tag
      init_sql_b64 = base64encode(templatefile("${path.module}/templates/clickhouse-init.sql.tftpl", {
        clickhouse_db    = var.clickhouse_db
        clickhouse_table = var.clickhouse_table
      }))
    })
  }
}

# Backends

resource "yandex_compute_instance" "backends" {
  count       = var.backend_count
  name        = local.backend_names[count.index]
  hostname    = local.backend_names[count.index]
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = local.vm_resources_default.cores
    memory        = local.vm_resources_default.memory
    core_fraction = local.vm_resources_default.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.backend.id]
  }

  metadata = {
    serial-port-enable = "1"
    user-data = templatefile("${path.module}/templates/backend-cloud-init.yaml.tftpl", {
      instance_name           = local.backend_names[count.index]
      ssh_user                = var.ssh_user
      ssh_public_key          = local.ssh_public_key
      clickhouse_host         = yandex_compute_instance.clickhouse.network_interface[0].ip_address
      clickhouse_user         = var.clickhouse_user
      clickhouse_password     = var.clickhouse_password
      flush_interval_seconds  = var.backend_flush_interval_seconds
      app_main_b64            = filebase64("${path.module}/../app/main.py")
      app_config_b64          = filebase64("${path.module}/../app/config.py")
      app_models_b64          = filebase64("${path.module}/../app/models.py")
      app_spool_b64           = filebase64("${path.module}/../app/spool.py")
      app_clickhouse_b64      = filebase64("${path.module}/../app/clickhouse_http.py")
      requirements_b64        = filebase64("${path.module}/../app/requirements.txt")
      service_b64             = base64encode(templatefile("${path.module}/templates/logbroker.service.tftpl", {}))
    })
  }
}

# Nginx

resource "yandex_compute_instance" "nginx" {
  name        = "nginx"
  hostname    = "nginx"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = local.vm_resources_default.cores
    memory        = local.vm_resources_default.memory
    core_fraction = local.vm_resources_default.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nginx.id]
  }

  metadata = {
    serial-port-enable = "1"
    user-data = templatefile("${path.module}/templates/nginx-cloud-init.yaml.tftpl", {
      instance_name  = "nginx"
      ssh_user       = var.ssh_user
      ssh_public_key = local.ssh_public_key
      nginx_conf_b64 = base64encode(templatefile("${path.module}/templates/nginx.conf.tftpl", {
        backend_ips = yandex_compute_instance.backends[*].network_interface[0].ip_address
      }))
    })
  }
}
