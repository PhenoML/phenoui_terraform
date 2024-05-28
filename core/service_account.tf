resource "google_service_account" "service_account" {
  project = google_project.core_project.project_id
  account_id   = "phenoui-core-sa"
  display_name = "PhenoUI Service Account"
  description = "Service account to handle all projects, modules and state files for PhenoUI."
}

resource "google_folder_iam_binding" "folder_admin" {
    folder = google_folder.core_folder.id
    role    = "roles/resourcemanager.folderAdmin"
    members = [
        "serviceAccount:${google_service_account.service_account.email}",
    ]
}

resource "google_folder_iam_binding" "service_account_admin" {
  folder = google_folder.core_folder.id
  role    = "roles/iam.serviceAccountAdmin"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "project_creator" {
  folder = google_folder.core_folder.id
  role    = "roles/resourcemanager.projectCreator"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "project_deleter" {
  folder = google_folder.core_folder.id
  role    = "roles/resourcemanager.projectDeleter"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "project_mover" {
  folder = google_folder.core_folder.id
  role    = "roles/resourcemanager.projectMover"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "project_iam_admin" {
  folder = google_folder.core_folder.id
  role    = "roles/resourcemanager.projectIamAdmin"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "billing_project_manager" {
  folder = google_folder.core_folder.id
  role    = "roles/billing.projectManager"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "quota_administrator" {
  folder = google_folder.core_folder.id
  role    = "roles/servicemanagement.quotaAdmin"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_folder_iam_binding" "storage_admin" {
  folder = google_folder.core_folder.id
  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_organization_iam_binding" "organization_role_viewer" {
  org_id = module.global.org_id
  role    = "roles/iam.organizationRoleViewer"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_organization_iam_binding" "billing_user" {
  org_id = module.global.org_id
  role    = "roles/billing.user"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}

resource "google_organization_iam_binding" "billing_viewer" {
  org_id = module.global.org_id
  role    = "roles/billing.viewer"
  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]
}
