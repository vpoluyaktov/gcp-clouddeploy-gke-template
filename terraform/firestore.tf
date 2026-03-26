# Firestore database (Native mode)
resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = var.firestore_database_name
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.apis]
}

# Seed the greeting document so the API can read it on first deploy
resource "google_firestore_document" "greeting" {
  project     = var.project_id
  database    = google_firestore_database.main.name
  collection  = "greetings"
  document_id = "hello"

  fields = jsonencode({
    message = { stringValue = "Hello World!" }
  })
}
