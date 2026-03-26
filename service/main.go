package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"gcp-clouddeploy-gke-template/internal/config"
	"gcp-clouddeploy-gke-template/internal/server"
	"gcp-clouddeploy-gke-template/internal/store"
)

func main() {
	cfg := config.Load()

	var st store.Store
	if cfg.ProjectID != "" {
		ctx := context.Background()
		fs, err := store.NewFirestoreStore(ctx, cfg.ProjectID, cfg.FirestoreDatabaseName)
		if err != nil {
			log.Fatalf("Failed to initialize Firestore: %v", err)
		}
		defer func() {
			if err := fs.Close(); err != nil {
				log.Printf("Error closing Firestore: %v", err)
			}
		}()
		st = fs
		log.Printf("Firestore connected: project=%s database=%s", cfg.ProjectID, cfg.FirestoreDatabaseName)
	} else {
		log.Println("GCP_PROJECT_ID not set — running without Firestore (using fallback greeting)")
	}

	srv := server.New(cfg, st)
	mux := srv.SetupRoutes()

	httpServer := &http.Server{
		Addr:    fmt.Sprintf(":%s", cfg.Port),
		Handler: mux,
	}

	log.Printf("Starting gcp-clouddeploy-gke-template service version=%s env=%s port=%s", cfg.Version, cfg.Environment, cfg.Port)

	go func() {
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
	log.Println("Server exited")
}
