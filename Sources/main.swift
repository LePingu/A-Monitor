import Cocoa

// Create and run the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// This is required to make the app run as a UI application
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
