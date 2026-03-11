variable "cloud_id" {
  description = "Yandex Cloud cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "zone" {
  description = "Availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "ssh_user" {
  description = "SSH username created on every VM"
  type        = string
  default     = "ycuser"
}

variable "ssh_public_key_path" {
  description = "Absolute path to the public SSH key"
  type        = string
}

variable "backend_count" {
  description = "Number of backend logbroker instances"
  type        = number
  default     = 2

  validation {
    condition     = var.backend_count >= 1
    error_message = "backend_count must be at least 1"
  }
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "hw2-vpc"
}

variable "public_subnet_name" {
  description = "Public subnet name"
  type        = string
  default     = "hw2-public"
}

variable "private_subnet_name" {
  description = "Private subnet name required by the homework"
  type        = string
  default     = "hw2-network"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = list(string)
  default     = ["10.10.2.0/24"]
}

variable "clickhouse_db" {
  description = "Demo database name"
  type        = string
  default     = "default"
}

variable "clickhouse_table" {
  description = "Demo table created during bootstrap"
  type        = string
  default     = "kek"
}

variable "clickhouse_user" {
  description = "ClickHouse user used by logbroker"
  type        = string
  default     = "logbroker"
}

variable "clickhouse_password" {
  description = "ClickHouse password used by logbroker"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.clickhouse_password) > 0
    error_message = "clickhouse_password must not be empty"
  }
}

variable "clickhouse_image_tag" {
  description = "ClickHouse docker image tag"
  type        = string
  default     = "latest"
}

variable "backend_flush_interval_seconds" {
  description = "Flush interval for the persistent log buffer"
  type        = number
  default     = 1
}
