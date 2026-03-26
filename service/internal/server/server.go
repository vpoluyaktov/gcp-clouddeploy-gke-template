package server

import (
	"html/template"
	"net/http"

	"gcp-clouddeploy-gke-template/internal/config"
	"gcp-clouddeploy-gke-template/internal/store"
	"gcp-clouddeploy-gke-template/internal/templates"
)

type Server struct {
	cfg       *config.Config
	store     store.Store
	indexTmpl *template.Template
}

func New(cfg *config.Config, st store.Store) *Server {
	tmpl := template.Must(template.ParseFS(templates.FS, "index.html"))
	return &Server{cfg: cfg, store: st, indexTmpl: tmpl}
}

func (s *Server) SetupRoutes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/api/hello", s.handleAPIHello)
	mux.HandleFunc("/", s.handleIndex)
	return mux
}
