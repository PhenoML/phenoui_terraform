resource "google_folder" "core_folder" {
  display_name = module.global.folder
  parent       = "organizations/${module.global.org_id}"
}

resource "google_project" "core_project" {
  name       = module.global.project
  project_id = module.global.project
  folder_id = google_folder.core_folder.id
  billing_account = module.global.billing_account
}

resource "google_project_service" "cloud_resource_manager_api" {
  project = google_project.core_project.project_id
  service = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "iam_api" {
  project = google_project.core_project.project_id
  service = "iam.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "service_usage_api" {
  project = google_project.core_project.project_id
  service = "serviceusage.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "cloud_billing_api" {
  project = google_project.core_project.project_id
  service = "cloudbilling.googleapis.com"
  disable_dependent_services = true
}

