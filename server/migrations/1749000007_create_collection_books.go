package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collectionsCollection, err := app.FindCollectionByNameOrId("collections")
		if err != nil {
			return err
		}

		booksCollection, err := app.FindCollectionByNameOrId("books")
		if err != nil {
			return err
		}

		collection := core.NewBaseCollection("collection_books")

		// Access rules go through the parent collection's user field
		collection.ListRule = types.Pointer("@request.auth.id != '' && collection.user = @request.auth.id")
		collection.ViewRule = types.Pointer("@request.auth.id != '' && collection.user = @request.auth.id")
		collection.CreateRule = types.Pointer("@request.auth.id != ''")
		collection.UpdateRule = types.Pointer("@request.auth.id != '' && collection.user = @request.auth.id")
		collection.DeleteRule = types.Pointer("@request.auth.id != '' && collection.user = @request.auth.id")

		collection.Fields.Add(
			&core.RelationField{
				Name:          "collection",
				Required:      true,
				MaxSelect:     1,
				CollectionId:  collectionsCollection.Id,
				CascadeDelete: true,
			},
			&core.RelationField{
				Name:          "book",
				Required:      true,
				MaxSelect:     1,
				CollectionId:  booksCollection.Id,
				CascadeDelete: true,
			},
			&core.NumberField{Name: "sort_order"},
		)

		collection.AddIndex("idx_collection_books_unique", true, "collection, book", "")

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("collection_books")
		if err != nil {
			return nil
		}
		return app.Delete(collection)
	})
}
