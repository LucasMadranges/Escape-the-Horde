package routes

import (
	"escape-the-horde-api/ent"
	"escape-the-horde-api/handlers"

	"github.com/gofiber/fiber/v2"
)

func Setup(app *fiber.App, client *ent.Client) {
	ph := handlers.NewPlayerHandler(client)

	api := app.Group("/api")

	players := api.Group("/players")
	players.Get("/leaderboard", ph.GetLeaderboard)
	players.Get("/", ph.GetAll)
	players.Get("/:id", ph.GetByID)
	players.Post("/", ph.Create)
	players.Patch("/:id/xp", ph.AddExperience)
	players.Patch("/:id/gold", ph.UpdateGold)
	players.Delete("/:id", ph.Delete)
}
