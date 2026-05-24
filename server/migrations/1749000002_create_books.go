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

		collection := core.NewBaseCollection("books")

		collection.ListRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.CreateRule = types.Pointer("@request.auth.id != ''")
		collection.UpdateRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")
		collection.DeleteRule = types.Pointer("@request.auth.id != '' && user = @request.auth.id")

		collection.Fields.Add(
			&core.TextField{Name: "title", Required: true, Max: 500},
			&core.TextField{Name: "author", Max: 500},
			&core.TextField{Name: "description"},
			&core.FileField{
				Name:      "cover_image",
				MaxSelect: 1,
				MaxSize:   10 << 20, // 10MB
				MimeTypes: []string{"image/jpeg", "image/png", "image/webp", "image/gif"},
			},
			&core.FileField{
				Name:      "epub_file",
				Required:  true,
				MaxSelect: 1,
				MaxSize:   100 << 20, // 100MB
				MimeTypes: []string{"application/epub+zip", "application/octet-stream"},
			},
			&core.TextField{Name: "isbn", Max: 20},
			&core.TextField{Name: "language", Max: 10},
			&core.TextField{Name: "publisher", Max: 500},
			&core.DateField{Name: "publish_date"},
			&core.NumberField{Name: "total_chapters"},
			&core.TextField{Name: "file_hash", Max: 128},
			&core.TextField{Name: "format", Max: 20},
			&core.RelationField{
				Name:          "user",
				Required:      true,
				MaxSelect:     1,
				CollectionId:  usersCollection.Id,
				CascadeDelete: true,
			},
		)

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("books")
		if err != nil {
			return nil
		}
		return app.Delete(collection)
	})
}
