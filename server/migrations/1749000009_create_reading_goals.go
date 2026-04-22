package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		usersCollection, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		collection := core.NewBaseCollection("reading_goals")

		collection.ListRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.CreateRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.UpdateRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.DeleteRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")

		collection.Fields.Add(
			&core.RelationField{
				Name:          "user",
				Required:      true,
				MaxSelect:     1,
				CollectionId:  usersCollection.Id,
				CascadeDelete: true,
			},
			&core.NumberField{Name: "year"},
			&core.NumberField{Name: "books_goal"},
			&core.NumberField{Name: "minutes_per_day_goal"},
		)

		collection.AddIndex("idx_reading_goals_user_year", true, "user, year", "")

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("reading_goals")
		if err != nil {
			return nil
		}
		return app.Delete(collection)
	})
}
