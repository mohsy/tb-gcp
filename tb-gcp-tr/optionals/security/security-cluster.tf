data "terraform_remote_state" "landingzone" {
  backend = "gcs"
  config = {
    bucket  = var.terraform_state_bucket
    prefix  = "landingZone"
  }
}

provider "google" {
  region = data.terraform_remote_state.landingzone.outputs.region
  zone   = data.terraform_remote_state.landingzone.outputs.region_zone
  version = "~> 2.5"
}

provider "google-beta" {
  alias   = "shared-vpc"
  region  = data.terraform_remote_state.landingzone.outputs.region
  zone    = data.terraform_remote_state.landingzone.outputs.region_zone
  project = data.terraform_remote_state.landingzone.outputs.shared_networking_id
  version = "~> 2.5"
}

provider "kubernetes" {
  alias = "k8s"
  version = "~> 1.10.0"
}

terraform {
  backend "gcs" {}
}

module "gke-security" {
  source = "../../kubernetes-cluster-creation"

  providers = {
    google                 = google
    google-beta.shared-vpc = google-beta.shared-vpc
  }

  region               = data.terraform_remote_state.landingzone.outputs.region
  sharedvpc_project_id = data.terraform_remote_state.landingzone.outputs.shared_networking_id
  sharedvpc_network    = data.terraform_remote_state.landingzone.outputs.shared_vpc_name

  cluster_enable_private_nodes  = var.cluster_sec_enable_private_nodes
  cluster_project_id            = data.terraform_remote_state.landingzone.outputs.shared_security_id
  cluster_subnetwork            = var.cluster_sec_subnetwork
  cluster_service_account       = var.cluster_sec_service_account
  cluster_service_account_roles = var.cluster_sec_service_account_roles
  cluster_name                  = var.cluster_sec_name
  cluster_pool_name             = var.cluster_sec_pool_name
  cluster_master_cidr           = var.cluster_sec_master_cidr
  cluster_master_authorized_cidrs = concat(
  var.cluster_sec_master_authorized_cidrs,
  [
    merge(
    {
      "display_name" = "initial-admin-ip"
    },
    {
      "cidr_block" = join("", [data.terraform_remote_state.landingzone.outputs.clusters_master_whitelist_ip, "/32"])
    },
    ),
  ],
  )
  cluster_min_master_version = var.cluster_sec_min_master_version
  istio_status               = var.istio_status
  cluster_oauth_scopes       = var.cluster_sec_oauth_scope

  apis_dependency          = data.terraform_remote_state.landingzone.outputs.all_apis_enabled
  shared_vpc_dependency    = data.terraform_remote_state.landingzone.outputs.gke_subnetwork_ids
  gke_pod_network_name     = var.gke_pod_network_name
  gke_service_network_name = var.gke_service_network_name
}