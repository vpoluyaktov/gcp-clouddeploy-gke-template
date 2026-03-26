package config

import "os"

type Config struct {
	Port                  string
	Version               string
	Environment           string
	ProjectID             string
	FirestoreDatabaseName string
}

func Load() *Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	version := os.Getenv("APP_VERSION")
	if version == "" {
		version = "dev"
	}
	env := os.Getenv("ENVIRONMENT")
	if env == "" {
		env = "local"
	}
	projectID := os.Getenv("GCP_PROJECT_ID")
	firestoreDB := os.Getenv("FIRESTORE_DATABASE_NAME")
	if firestoreDB == "" {
		firestoreDB = "(default)"
	}
	return &Config{
		Port:                  port,
		Version:               version,
		Environment:           env,
		ProjectID:             projectID,
		FirestoreDatabaseName: firestoreDB,
	}
}
