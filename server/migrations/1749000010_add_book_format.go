package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("books")
		if err != nil {
			return err
		}

		if collection.Fields.GetByName("format") == nil {
			collection.Fields.Add(&core.TextField{
				Name: "format",
				Max:  20,
			})
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("books")
		if err != nil {
			return nil
		}

		if field := collection.Fields.GetByName("format"); field != nil {
			collection.Fields.RemoveByName("format")
		}

		return app.Save(collection)
	})
}
