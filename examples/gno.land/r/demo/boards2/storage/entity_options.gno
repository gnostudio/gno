package storage

const (
	FieldID   = "id"
	FieldSlug = "slug"
)

type EntityOption func(*Entity)

func WithVersion(v string) EntityOption {
	return func(e *Entity) {
		e.version = v
	}
}

func WithDefault(field string, value interface{}) EntityOption {
	return func(e *Entity) {
		if fn, ok := value.(func() interface{}); ok {
			e.Set(field, fn())
		} else {
			e.Set(field, value)
		}
	}
}

func WithField(field string, value interface{}) EntityOption {
	return func(e *Entity) {
		e.Set(field, value)
	}
}

func WithID(id uint64) EntityOption {
	return func(e *Entity) {
		e.Set(FieldID, id)
	}
}

func WithSlug(s string) EntityOption {
	return func(e *Entity) {
		e.Set(FieldSlug, s)
	}
}
