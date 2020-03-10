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

module "gke-operations" {
  source = "../../kubernetes-cluster-creation"

  providers = {
    google                 = google
    google-beta.shared-vpc = google-beta.shared-vpc
    kubernetes             = kubernetes.gke-operations
  }

  region               = data.terraform_remote_state.landingzone.outputs.region
  sharedvpc_project_id = data.terraform_remote_state.landingzone.outputs.shared_networking_id
  sharedvpc_network    = data.terraform_remote_state.landingzone.outputs.shared_vpc_name

  cluster_enable_private_nodes = var.cluster_opt_enable_private_nodes
  cluster_project_id           = data.terraform_remote_state.landingzone.outputs.shared_operations_id
  cluster_subnetwork           = var.cluster_opt_subnetwork
  cluster_service_account      = var.cluster_opt_service_account
  cluster_name                 = var.cluster_opt_name
  cluster_pool_name            = var.cluster_opt_pool_name
  cluster_master_cidr          = var.cluster_opt_master_cidr
  cluster_master_authorized_cidrs = concat(
  var.cluster_opt_master_authorized_cidrs,
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
  cluster_min_master_version = var.cluster_opt_min_master_version

  apis_dependency          = data.terraform_remote_state.landingzone.outputs.all_apis_enabled
  istio_status             = var.istio_status
  istio_permissive_mtls    = "true"
  shared_vpc_dependency    = data.terraform_remote_state.landingzone.outputs.gke_subnetwork_ids
  gke_pod_network_name     = var.gke_pod_network_name
  gke_service_network_name = var.gke_service_network_name
}

provider "kubernetes" {
  alias                  = "gke-operations"
  host                   = "https://${module.gke-operations.cluster_endpoint}"
  load_config_file       = false
  cluster_ca_certificate = base64decode(module.gke-operations.cluster_ca_certificate)
  token                  = data.terraform_remote_state.landingzone.outputs.access_token
  version = "~> 1.10.0"
}