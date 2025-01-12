package storage

import (
	"testing"
	"time"

	"gno.land/r/demo/boards2/storage"
)

func TestDefineEntity(t *testing.T) {
	entityName := "Foo"
	newEntity := storage.DefineEntity(
		entityName,
		storage.IndexID,
		// storage.WithDefault("value", 42),
		// storage.WithDefault("createdAt", func() interface{} {
		// 	return time.Now()
		// }),
	)

	storage.RegisterIndexer(entityName, "slug", storage.IndexSlug)

	newEntity(storage.WithID(1), storage.WithField(storage.FieldSlug, "b"))
	newEntity(storage.WithID(2), storage.WithField(storage.FieldSlug, "a"))

	storage.Get(entityName).Iterate("", "", func(k string, v interface{}) bool {
		println("==> ", k)
		foo := v.(*storage.Entity)
		println(foo.Get("id").(uint64))
		println(foo.Get("slug"))
		// println(foo.Get("value").(int))
		// println(foo.Get("createdAt").(time.Time))
		println()
		return false
	})

	storage.GetByIndex(entityName, "slug").Iterate("", "", func(k string, v interface{}) bool {
		println("==> ", k)
		foo := v.(*storage.Entity)
		println(foo.Get("id").(uint64))
		println(foo.Get("slug"))
		// println(foo.Get("value").(int))
		// println(foo.Get("createdAt").(time.Time))
		println()
		return false
	})
}
