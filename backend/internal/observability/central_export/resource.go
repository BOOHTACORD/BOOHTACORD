package centralexport

import "go.opentelemetry.io/otel/attribute"

func (r *Runtime) Attributes() []attribute.KeyValue {
	i := r.Identity()
	attrs := []attribute.KeyValue{attribute.String("service.namespace", "boohtacord"), attribute.String("service.instance.id", r.Instance())}
	if i.Valid() == nil {
		attrs = append(attrs, attribute.String("boohtacord.installation.id", i.ID))
	}
	return attrs
}
