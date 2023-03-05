variable "region" {
  default = "eu-central-1"
}

variable "prefix" {}

variable "timeout" {
  default = 900
}

variable "python_file_path" {}

variable "docker_file_path" {}

variable "cron_schedule" {}

variable "docker_build_path" {}

variable "helper_file_dir" {}

variable "memory" {
  default = 128
}

variable "ephemeral_storage" {
  default = 512
}

variable "iam_role_name" {}