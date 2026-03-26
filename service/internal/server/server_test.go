package server

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"gcp-clouddeploy-gke-template/internal/config"
)

// mockStore implements store.Store for testing
type mockStore struct {
	message string
	err     error
}

func (m *mockStore) GetGreeting(ctx context.Context) (string, error) {
	return m.message, m.err
}

func (m *mockStore) Close() error { return nil }

func newTestServer() *Server {
	cfg := &config.Config{
		Port:        "8080",
		Version:     "1.0.0",
		Environment: "test",
	}
	return New(cfg, nil)
}

func TestHandleHealth(t *testing.T) {
	srv := newTestServer()
	mux := srv.SetupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "application/json" {
		t.Errorf("expected Content-Type application/json, got %s", ct)
	}

	var resp healthResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Status != "ok" {
		t.Errorf("expected status=ok, got %s", resp.Status)
	}
	if resp.Version != "1.0.0" {
		t.Errorf("expected version=1.0.0, got %s", resp.Version)
	}
	if resp.Environment != "test" {
		t.Errorf("expected environment=test, got %s", resp.Environment)
	}
}

func TestHandleAPIHello(t *testing.T) {
	srv := newTestServer()
	mux := srv.SetupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/api/hello", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "application/json" {
		t.Errorf("expected Content-Type application/json, got %s", ct)
	}

	var resp helloResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Message != "Hello World!" {
		t.Errorf("expected message=Hello World!, got %s", resp.Message)
	}
	if resp.Version != "1.0.0" {
		t.Errorf("expected version=1.0.0, got %s", resp.Version)
	}
	if resp.Timestamp == "" {
		t.Error("expected non-empty timestamp")
	}
}

func TestHandleIndex(t *testing.T) {
	srv := newTestServer()
	mux := srv.SetupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "text/html; charset=utf-8" {
		t.Errorf("expected Content-Type text/html; charset=utf-8, got %s", ct)
	}

	body := w.Body.String()
	if !strings.Contains(body, "id=\"greeting\"") {
		t.Error("expected body to contain greeting element")
	}
	if !strings.Contains(body, "fetch('/api/hello')") {
		t.Error("expected body to contain fetch call to /api/hello")
	}
	if !strings.Contains(body, "1.0.0") {
		t.Error("expected body to contain version '1.0.0'")
	}
	if !strings.Contains(body, "test") {
		t.Error("expected body to contain environment 'test'")
	}
}

func TestNewServerParsesTemplate(t *testing.T) {
	srv := newTestServer()
	if srv.indexTmpl == nil {
		t.Error("expected indexTmpl to be non-nil after New()")
	}
}

func TestHandleAPIHelloWithStore(t *testing.T) {
	cfg := &config.Config{
		Port:        "8080",
		Version:     "1.0.0",
		Environment: "test",
	}
	ms := &mockStore{message: "Hello from Firestore!"}
	srv := New(cfg, ms)
	mux := srv.SetupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/api/hello", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	var resp helloResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Message != "Hello from Firestore!" {
		t.Errorf("expected message='Hello from Firestore!', got %s", resp.Message)
	}
}

func TestHandleAPIHelloStoreError(t *testing.T) {
	cfg := &config.Config{
		Port:        "8080",
		Version:     "1.0.0",
		Environment: "test",
	}
	ms := &mockStore{err: context.DeadlineExceeded}
	srv := New(cfg, ms)
	mux := srv.SetupRoutes()

	req := httptest.NewRequest(http.MethodGet, "/api/hello", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}

	var resp helloResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Message != "Hello World!" {
		t.Errorf("expected fallback message='Hello World!', got %s", resp.Message)
	}
}
