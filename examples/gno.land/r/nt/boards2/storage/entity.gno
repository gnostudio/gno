package storage

import "gno.land/p/demo/avl"

type Entity struct {
	name    string
	version string
	fields  *avl.Tree
}

func (e Entity) Name() string {
	return e.name
}

func (e Entity) Version() string {
	return e.version
}

func (e Entity) Has(field string) bool {
	return e.fields.Has(field)
}

func (e Entity) Get(field string) (value interface{}) {
	v, _ := e.fields.Get(field)
	return v
}

func (e *Entity) Set(field string, value interface{}) (updated bool) {
	return e.fields.Set(field, value)
}

func (e *Entity) Remove(field string) (value interface{}, removed bool) {
	return e.fields.Remove(field)
}

func (e Entity) Fields() (names []string) {
	e.fields.Iterate("", "", func(name string, _ interface{}) bool {
		names = append(names, name)
		return false
	})
	return
}
