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

		supportedMimeTypes := []string{
			"application/epub+zip",
			"application/pdf",
			"application/zip",
			"application/vnd.comicbook+zip",
			"application/x-cbz",
			"application/xhtml+xml",
			"text/html",
			"text/plain",
			"application/octet-stream",
		}

		if legacyField, ok := collection.Fields.GetByName("epub_file").(*core.FileField); ok {
			legacyField.Required = false
			legacyField.MaxSelect = 1
			legacyField.MaxSize = 100 << 20
			legacyField.MimeTypes = supportedMimeTypes
		}

		if currentField, ok := collection.Fields.GetByName("book_file").(*core.FileField); ok {
			currentField.Required = false
			currentField.MaxSelect = 1
			currentField.MaxSize = 100 << 20
			currentField.MimeTypes = supportedMimeTypes
		} else {
			collection.Fields.Add(&core.FileField{
				Name:      "book_file",
				MaxSelect: 1,
				MaxSize:   100 << 20, // 100MB
				MimeTypes: supportedMimeTypes,
			})
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("books")
		if err != nil {
			return nil
		}

		if field := collection.Fields.GetByName("book_file"); field != nil {
			collection.Fields.RemoveByName("book_file")
		}

		if legacyField, ok := collection.Fields.GetByName("epub_file").(*core.FileField); ok {
			legacyField.Required = true
			legacyField.MaxSelect = 1
			legacyField.MaxSize = 100 << 20
			legacyField.MimeTypes = []string{
				"application/epub+zip",
				"application/octet-stream",
			}
		}

		return app.Save(collection)
	})
}
