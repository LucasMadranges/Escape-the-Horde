package dto

import "github.com/google/uuid"

// PlayerResponse est la représentation JSON d'un joueur renvoyée par l'API.
// Le niveau est calculé à la volée depuis l'expérience et injecté ici.
type PlayerResponse struct {
	ID         uuid.UUID `json:"id"`
	Username   string    `json:"username"`
	Level      int       `json:"level"`
	Experience int       `json:"experience"`
	Gold       int       `json:"gold"`
	CreatedAt  string    `json:"created_at"`
	UpdatedAt  string    `json:"updated_at"`
}
