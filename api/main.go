package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"escape-the-horde-api/ent"
	"escape-the-horde-api/ent/migrate"
	"escape-the-horde-api/routes"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	_ "github.com/lib/pq"
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getDSN() string {
	host := getEnv("POSTGRES_HOST", "localhost")
	port := getEnv("POSTGRES_PORT", "5432")
	user := getEnv("POSTGRES_USER", "user")
	password := getEnv("POSTGRES_PASSWORD", "root")
	dbname := getEnv("POSTGRES_DB", "escapethehorde")
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)
}

func main() {
	client, err := ent.Open("postgres", getDSN())
	if err != nil {
		log.Fatalf("Connexion BDD impossible: %v", err)
	}
	defer client.Close()

	if err := client.Schema.Create(context.Background(), migrate.WithDropIndex(true)); err != nil {
		log.Fatalf("Migration schema: %v", err)
	}

	app := fiber.New(fiber.Config{
		AppName: "Escape the Horde API",
	})

	app.Use(logger.New())
	app.Use(recover.New())

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	routes.Setup(app, client)

	port := getEnv("PORT", "3000")
	log.Printf("API demarree sur le port %s", port)
	log.Fatal(app.Listen(":" + port))
}
