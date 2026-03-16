package handlers

import (
	"escape-the-horde-api/ent"
	"escape-the-horde-api/ent/player"
	"escape-the-horde-api/utils"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type PlayerHandler struct {
	client *ent.Client
}

func NewPlayerHandler(client *ent.Client) *PlayerHandler {
	return &PlayerHandler{client: client}
}

type playerResponse struct {
	ID         uuid.UUID `json:"id"`
	Username   string    `json:"username"`
	Level      int       `json:"level"`
	Experience int       `json:"experience"`
	Gold       int       `json:"gold"`
	CreatedAt  string    `json:"created_at"`
	UpdatedAt  string    `json:"updated_at"`
}

func toResponse(p *ent.Player) playerResponse {
	return playerResponse{
		ID:         p.ID,
		Username:   p.Username,
		Level:      utils.CalculateLevel(p.Experience),
		Experience: p.Experience,
		Gold:       p.Gold,
		CreatedAt:  p.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:  p.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

// GetAll - GET /api/players
func (h *PlayerHandler) GetAll(c *fiber.Ctx) error {
	players, err := h.client.Player.Query().All(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	result := make([]playerResponse, len(players))
	for i, p := range players {
		result[i] = toResponse(p)
	}
	return c.JSON(result)
}

// GetByID - GET /api/players/:id
func (h *PlayerHandler) GetByID(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID invalide"})
	}
	p, err := h.client.Player.Get(c.Context(), id)
	if err != nil {
		if ent.IsNotFound(err) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Joueur introuvable"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(toResponse(p))
}

// Create - POST /api/players
func (h *PlayerHandler) Create(c *fiber.Ctx) error {
	var body struct {
		Username string `json:"username"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Body invalide"})
	}
	p, err := h.client.Player.Create().
		SetUsername(body.Username).
		Save(c.Context())
	if err != nil {
		if ent.IsConstraintError(err) {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "Username deja utilise"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(toResponse(p))
}

// AddExperience - PATCH /api/players/:id/xp
func (h *PlayerHandler) AddExperience(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID invalide"})
	}
	var body struct {
		Amount int `json:"amount"`
	}
	if err := c.BodyParser(&body); err != nil || body.Amount <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "amount doit etre un entier positif"})
	}
	p, err := h.client.Player.UpdateOneID(id).
		AddExperience(body.Amount).
		Save(c.Context())
	if err != nil {
		if ent.IsNotFound(err) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Joueur introuvable"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(toResponse(p))
}

// UpdateGold - PATCH /api/players/:id/gold
func (h *PlayerHandler) UpdateGold(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID invalide"})
	}
	var body struct {
		Amount int `json:"amount"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Body invalide"})
	}
	p, err := h.client.Player.UpdateOneID(id).
		AddGold(body.Amount).
		Save(c.Context())
	if err != nil {
		if ent.IsNotFound(err) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Joueur introuvable"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(toResponse(p))
}

// Delete - DELETE /api/players/:id
func (h *PlayerHandler) Delete(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID invalide"})
	}
	err = h.client.Player.DeleteOneID(id).Exec(c.Context())
	if err != nil {
		if ent.IsNotFound(err) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Joueur introuvable"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// GetLeaderboard - GET /api/players/leaderboard
func (h *PlayerHandler) GetLeaderboard(c *fiber.Ctx) error {
	players, err := h.client.Player.Query().
		Order(ent.Desc(player.FieldExperience)).
		Limit(10).
		All(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": err.Error()})
	}
	result := make([]playerResponse, len(players))
	for i, p := range players {
		result[i] = toResponse(p)
	}
	return c.JSON(result)
}
