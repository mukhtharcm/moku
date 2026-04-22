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

		booksCollection, err := app.FindCollectionByNameOrId("books")
		if err != nil {
			return err
		}

		collection := core.NewBaseCollection("reading_sessions")

		collection.ListRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.CreateRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.UpdateRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.DeleteRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")

		collection.Fields.Add(
			&core.RelationField{
				Name:          "book",
				Required:      true,
				MaxSelect:     1,
				CollectionId:  booksCollection.Id,
				CascadeDelete: true,
			},
			&core.RelationField{
				Name:          "user",
				Required:      true,
				MaxSelect:     1,
				CollectionId:  usersCollection.Id,
				CascadeDelete: true,
			},
			&core.TextField{Name: "book_title"},
			&core.DateField{Name: "started_at"},
			&core.DateField{Name: "ended_at"},
			&core.NumberField{Name: "duration_seconds"},
			&core.NumberField{Name: "start_chapter"},
			&core.NumberField{Name: "end_chapter"},
		)

		collection.AddIndex("idx_reading_sessions_book_user", false, "book, user", "")
		collection.AddIndex("idx_reading_sessions_user_started", false, "user, started_at", "")

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("reading_sessions")
		if err != nil {
			return nil
		}
		return app.Delete(collection)
	})
}
