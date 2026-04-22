package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collections := []string{
			"books",
			"reading_progress",
			"bookmarks",
			"highlights",
			"collections",
			"collection_books",
			"reading_sessions",
			"reading_goals",
		}

		for _, name := range collections {
			collection, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				continue
			}
			if collection.Fields.GetByName("deleted_at") == nil {
				collection.Fields.Add(&core.DateField{Name: "deleted_at"})
			}
			if err := app.Save(collection); err != nil {
				return err
			}
		}

		return nil
	}, func(app core.App) error {
		collections := []string{
			"books",
			"reading_progress",
			"bookmarks",
			"highlights",
			"collections",
			"collection_books",
			"reading_sessions",
			"reading_goals",
		}

		for _, name := range collections {
			collection, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				continue
			}
			if field := collection.Fields.GetByName("deleted_at"); field != nil {
				collection.Fields.RemoveByName("deleted_at")
			}
			if err := app.Save(collection); err != nil {
				return err
			}
		}

		return nil
	})
}
