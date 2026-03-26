package config

import (
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("APP_VERSION", "")
	t.Setenv("ENVIRONMENT", "")
	t.Setenv("GCP_PROJECT_ID", "")
	t.Setenv("FIRESTORE_DATABASE_NAME", "")

	cfg := Load()

	if cfg.Port != "8080" {
		t.Errorf("expected Port=8080, got %s", cfg.Port)
	}
	if cfg.Version != "dev" {
		t.Errorf("expected Version=dev, got %s", cfg.Version)
	}
	if cfg.Environment != "local" {
		t.Errorf("expected Environment=local, got %s", cfg.Environment)
	}
	if cfg.ProjectID != "" {
		t.Errorf("expected ProjectID='', got %s", cfg.ProjectID)
	}
	if cfg.FirestoreDatabaseName != "(default)" {
		t.Errorf("expected FirestoreDatabaseName=(default), got %s", cfg.FirestoreDatabaseName)
	}
}

func TestLoadFromEnv(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("APP_VERSION", "1.2.3")
	t.Setenv("ENVIRONMENT", "staging")
	t.Setenv("GCP_PROJECT_ID", "my-project")
	t.Setenv("FIRESTORE_DATABASE_NAME", "my-db")

	cfg := Load()

	if cfg.Port != "9090" {
		t.Errorf("expected Port=9090, got %s", cfg.Port)
	}
	if cfg.Version != "1.2.3" {
		t.Errorf("expected Version=1.2.3, got %s", cfg.Version)
	}
	if cfg.Environment != "staging" {
		t.Errorf("expected Environment=staging, got %s", cfg.Environment)
	}
	if cfg.ProjectID != "my-project" {
		t.Errorf("expected ProjectID=my-project, got %s", cfg.ProjectID)
	}
	if cfg.FirestoreDatabaseName != "my-db" {
		t.Errorf("expected FirestoreDatabaseName=my-db, got %s", cfg.FirestoreDatabaseName)
	}
}
