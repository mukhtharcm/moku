package main

import (
	"log"
	"net/http"
	"time"

	_ "github.com/moku/server/migrations"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/osutils"
)

func main() {
	app := pocketbase.New()

	// Register the migrate command (auto-create migration files in dev mode)
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: osutils.IsProbablyGoRun(),
	})

	bindRoutes(app)
	bindHooks(app)

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

// bindRoutes registers custom API routes.
func bindRoutes(app *pocketbase.PocketBase) {
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		// Health check
		e.Router.GET("/api/health", func(e *core.RequestEvent) error {
			return e.JSON(http.StatusOK, map[string]any{
				"status":  "ok",
				"service": "moku-server",
				"time":    time.Now().UTC().Format(time.RFC3339),
			})
		})

		return e.Next()
	})
}

// bindHooks registers lifecycle hooks for book-related operations.
func bindHooks(app *pocketbase.PocketBase) {
	// Validate book records before create
	app.OnRecordCreate("books").BindFunc(func(e *core.RecordEvent) error {
		title := e.Record.GetString("title")
		if title == "" {
			return apis.NewBadRequestError("Title is required", nil)
		}
		return e.Next()
	})

	// Set default reading progress on new reading_progress records
	app.OnRecordCreate("reading_progress").BindFunc(func(e *core.RecordEvent) error {
		if e.Record.GetFloat("overall_progress") == 0 {
			e.Record.Set("overall_progress", 0)
		}
		if e.Record.GetInt("current_chapter") == 0 {
			e.Record.Set("current_chapter", 0)
		}
		return e.Next()
	})

	// Log book updates
	app.OnRecordUpdate("books").BindFunc(func(e *core.RecordEvent) error {
		log.Printf("[moku] book updated: %s (%s)", e.Record.GetString("title"), e.Record.Id)
		return e.Next()
	})
}
