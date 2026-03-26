package server

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

type healthResponse struct {
	Status      string `json:"status"`
	Version     string `json:"version"`
	Environment string `json:"environment"`
}

type helloResponse struct {
	Message   string `json:"message"`
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
}

type indexData struct {
	Version     string
	Environment string
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	resp := healthResponse{
		Status:      "ok",
		Version:     s.cfg.Version,
		Environment: s.cfg.Environment,
	}
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("handleHealth encode error: %v", err)
	}
}

func (s *Server) handleAPIHello(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	message := "Hello World!"
	if s.store != nil {
		msg, err := s.store.GetGreeting(r.Context())
		if err != nil {
			log.Printf("handleAPIHello Firestore error (using fallback): %v", err)
		} else {
			message = msg
		}
	}

	resp := helloResponse{
		Message:   message,
		Version:   s.cfg.Version,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("handleAPIHello encode error: %v", err)
	}
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := indexData{
		Version:     s.cfg.Version,
		Environment: s.cfg.Environment,
	}
	if err := s.indexTmpl.Execute(w, data); err != nil {
		log.Printf("handleIndex template execute error: %v", err)
	}
}
