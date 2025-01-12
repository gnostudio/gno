package storage

import (
	"strings"

	"gno.land/p/demo/avl"
)

const (
	DefaultIndex   = "default"
	DefaultVersion = "v1"
)

var entities = avl.NewTree()

type EntityFactoryFn = func(...EntityOption) *Entity

// TODO: Implement entity migration suport
// TODO: Allow entity removal, get and set
// TODO: Allow iterating entities
// TODO: Allow adding new entity indexes

func DefineEntity(name string, fn IndexFn, defaults ...EntityOption) EntityFactoryFn {
	if fn == nil {
		panic("entity index function is required")
	}

	name = strings.TrimSpace(name)
	if name == "" {
		panic("entity name is required")
	}

	// Register a default index function for the new entity type
	indexers.Set(name, map[string]IndexFn{
		DefaultIndex: fn,
	})

	// Initialize a default index for the instances
	index := avl.NewTree() // string(index name) -> avl.Tree(string(key) -> *Entity)
	index.Set(DefaultIndex, avl.NewTree())
	entities.Set(name, index)

	// Return a factory to create new entity instances
	return func(options ...EntityOption) *Entity {
		e := &Entity{
			name:    name,
			version: DefaultVersion,
			fields:  avl.NewTree(),
		}

		for _, apply := range defaults {
			apply(e)
		}

		for _, apply := range options {
			apply(e)
		}

		indexEntity(e)
		return e
	}
}

func Get(entityName string) *avl.Tree {
	return GetByIndex(entityName, DefaultIndex)
}

func GetByIndex(entityName, indexName string) *avl.Tree {
	v, found := entities.Get(entityName)
	if !found {
		panic("entity type is not defined: " + entityName)
	}

	v, found = v.(*avl.Tree).Get(indexName)
	if !found {
		panic("entity index not found: " + indexName)
	}
	return v.(*avl.Tree)
}
