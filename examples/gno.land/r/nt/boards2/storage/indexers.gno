package storage

import (
	"encoding/binary"
	"strings"

	"gno.land/p/demo/avl"
)

type IndexFn = func(*Entity) string

var indexers = avl.NewTree() // string(entity name) -> map[string(index name)]IndexFn

func RegisterIndexer(entityName, indexName string, fn IndexFn) {
	v, found := indexers.Get(entityName)
	if !found {
		panic("entity type has no indexers: " + entityName)
	}

	indexName = strings.TrimSpace(indexName)
	if indexName == "" {
		panic("index name is empty")
	}

	funcs := v.(map[string]IndexFn)
	if _, exists := funcs[indexName]; exists {
		panic("index exists: " + indexName)
	}

	funcs[indexName] = fn
}

func IndexID(e *Entity) string {
	id, ok := e.Get("id").(uint64)
	if !ok {
		panic("id index value type must be uint64")
	}

	buf := make([]byte, 8)
	binary.BigEndian.PutUint64(buf, id)
	return string(buf)
}

func IndexSlug(e *Entity) string {
	slug, ok := e.Get("slug").(string)
	if !ok {
		panic("slug index value type must be string")
	}

	slug = strings.TrimSpace(slug)
	if slug == "" {
		panic("slug value is empty")
	}
	return slug
}

func indexEntity(e *Entity) {
	v, _ := entities.Get(e.Name())
	index := v.(*avl.Tree)

	v, found := indexers.Get(e.Name())
	if !found {
		panic("no indexers found for entity type: " + e.Name())
	}

	for name, fn := range v.(map[string]IndexFn) {
		key := fn(e)
		v, exists := index.Get(name)
		if !exists {
			v = avl.NewTree()
			index.Set(name, v)
		}

		idx := v.(*avl.Tree)
		idx.Set(key, e)
	}
}
