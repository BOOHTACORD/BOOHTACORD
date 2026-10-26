package centralprojection

// Client runtime is distinct from the resource's producer service. Never copy
// arbitrary resource metadata or infer a client platform from an API service.
func validClientPlatform(value string) bool {
	switch value {
	case "web", "android", "ios", "windows", "macos":
		return true
	default:
		return false
	}
}
