package store

import (
	"context"
	"fmt"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/option"
)

// Store defines the interface for fetching data from the persistence layer.
type Store interface {
	GetGreeting(ctx context.Context) (string, error)
	Close() error
}

// FirestoreStore implements Store using Google Cloud Firestore.
type FirestoreStore struct {
	client       *firestore.Client
	databaseName string
}

// NewFirestoreStore creates a new Firestore-backed store.
// projectID is the GCP project ID, databaseName is the Firestore database name.
// opts allows passing additional client options (e.g., for testing with an emulator).
func NewFirestoreStore(ctx context.Context, projectID, databaseName string, opts ...option.ClientOption) (*FirestoreStore, error) {
	client, err := firestore.NewClientWithDatabase(ctx, projectID, databaseName, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create Firestore client: %w", err)
	}
	return &FirestoreStore{client: client, databaseName: databaseName}, nil
}

// GetGreeting fetches the greeting message from the "greetings/hello" document.
func (s *FirestoreStore) GetGreeting(ctx context.Context) (string, error) {
	doc, err := s.client.Collection("greetings").Doc("hello").Get(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to get greeting document: %w", err)
	}
	message, ok := doc.Data()["message"].(string)
	if !ok {
		return "", fmt.Errorf("greeting document missing 'message' field or not a string")
	}
	return message, nil
}

// Close closes the Firestore client connection.
func (s *FirestoreStore) Close() error {
	return s.client.Close()
}
