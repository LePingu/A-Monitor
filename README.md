# macOS Notification Icon

This project is a macOS application that creates a notification icon in the status bar. It allows users to receive notifications and interact with the application through a menu.

## Project Structure

- **Sources/**: Contains the source code for the application.
  - **AppDelegate.swift**: Entry point of the application, managing the application lifecycle.
  - **StatusBarController.swift**: Manages the status bar item, including menu actions and notifications.
  - **NotificationManager.swift**: Handles the creation and display of notifications.

- **Resources/**: Contains image assets used in the application, such as icons for the status bar item.
  - **Assets.xcassets**: Directory for image assets.

- **Info.plist**: Configuration settings for the application, including the app's bundle identifier, version, and permissions required for notifications.

- **Package.swift**: Configuration file for Swift Package Manager, defining the package name, products, dependencies, and targets.

## Setup Instructions

1. Clone the repository:
   ```
   git clone https://github.com/LePingu/A-Monitor
   ```

2. Open the project in Xcode.

3. Build and run the application.

## Usage

Once the application is running, you will see an icon in the macOS status bar. Click on the icon to access the menu and receive notifications. The application will request permission to send notifications upon first launch.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.