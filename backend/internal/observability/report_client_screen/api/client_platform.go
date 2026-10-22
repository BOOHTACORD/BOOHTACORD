package reportscreenapi

// sampleClientPlatform reports the client runtime, never the API producer.
// The legacy desktop_native value does not identify an OS and remains unknown.
func sampleClientPlatform(platform string) string {
	switch platform {
	case "desktop_web", "android_web", "ios_web":
		return "web"
	case "android_native":
		return "android"
	case "ios_native":
		return "ios"
	case "windows_native":
		return "windows"
	case "macos_native":
		return "macos"
	default:
		return ""
	}
}
