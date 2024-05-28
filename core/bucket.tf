resource "google_storage_bucket" "tf_states" {
  name          = module.global.bucket
  project       = google_project.core_project.project_id
  location      = module.global.region
  force_destroy = true

  public_access_prevention = "enforced"
}