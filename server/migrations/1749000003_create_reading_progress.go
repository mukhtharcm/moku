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

		collection := core.NewBaseCollection("reading_progress")

		collection.ListRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.CreateRule = types.Pointer("@request.auth.id != ''")
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
			&core.NumberField{Name: "current_chapter"},
			&core.NumberField{Name: "chapter_progress"},
			&core.NumberField{Name: "overall_progress"},
			&core.TextField{Name: "last_position"},
			&core.DateField{Name: "last_read_at"},
		)

		collection.AddIndex("idx_reading_progress_book_user", true, "book, user", "")

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("reading_progress")
		if err != nil {
			return nil
		}
		return app.Delete(collection)
	})
}
