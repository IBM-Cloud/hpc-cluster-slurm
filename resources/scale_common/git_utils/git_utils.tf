###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
    GIT operations to clone specific branch or tag.
*/

variable "branch" {}
variable "tag" {}
variable "clone_path" {}

# data resource fetched the ansible-repo
data "github_repository" "ansible_repo" {
  full_name = "IBM/ibm-spectrum-scale-install-infra"
}

# clone the repo to the provided path
resource "null_resource" "create_clone_path" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "mkdir -p ${var.clone_path}"
  }
}

# clone the repo branch to the provided path
resource "null_resource" "clone_repo_branch" {
  count = var.tag == null ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "if [ -z \"$(ls -A ${var.clone_path})\" ]; then git -C ${var.clone_path} clone -b ${var.branch} ${data.github_repository.ansible_repo.http_clone_url}; fi"
  }
  depends_on = [null_resource.create_clone_path]
}

# clone the appropriate tag to the provided path
resource "null_resource" "clone_repo_tag" {
  count = var.tag != null ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "if [ -z \"$(ls -A ${var.clone_path})\" ]; then git -C ${var.clone_path} clone --branch ${var.tag} ${data.github_repository.ansible_repo.http_clone_url}; fi"
  }
  depends_on = [null_resource.create_clone_path]
}

output "clone_complete" {
  value      = true
  depends_on = [null_resource.clone_repo_branch, null_resource.clone_repo_tag]
}