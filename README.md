# 🚀 NexNote: AI-Powered Note-Taking Redefined

[![Flutter](https://flutter.dev/images/flutter-logo-sharing.png)](https://flutter.dev)  
**NexNote** is a modern, intuitive Flutter application designed for students, professionals, and anyone who loves organizing ideas. With AI-driven features like note comparison, enhancement, and merging, NexNote turns your scattered thoughts into structured brilliance. Say goodbye to mundane note-taking—welcome to the future!

## ✨ Why NexNote?
- **AI Insights**: Spot differences between notes in seconds and get smart suggestions.
- **Seamless Collaboration**: Share and explore community notes effortlessly.
- **Intuitive Design**: Clean dark theme with Poppins font for a premium reading experience.
- **Cross-Platform**: Built with Flutter for iOS, Android, web, and desktop.

Whether you're prepping for exams, brainstorming projects, or journaling daily wins, NexNote makes it fun and efficient!

## 📱 Key Features
- **Authentication Flow**: Secure login/signup with email, Google, and Apple support.
- **Dashboard**: Animated welcome with action buttons for Enhance, Compare, and Combine notes.
- **Navigation**: Smooth bottom bar (Home, Search, Add, Tools, Notes) and expandable sidebar (Profile, Favorites, Settings).
- **Note Management**: Grid-based community notes, search/filter/sort, and favorites collection.
- **Visual Polish**: Custom cards, animations, and responsive layouts.
- **Tech Stack**: Flutter, Google Fonts (Poppins), Material Design.

## 🖼️ Screenshots
### Landing Page
![Landing](screenshots/landing.png)  
*Welcome screen with illustration and quick access to login/signup.*

### Login Page
![Login](screenshots/login.png)  
*Clean form with social login options and forgot password link.*

### Sign-Up Page
![Signup](screenshots/signup.png)  
*Detailed form with terms agreement and social continue buttons.*

### Home Dashboard
![Home](screenshots/home.png)  
*Animated greeting, action buttons, and community notes grid.*

### Bottom Navigation
![Bottom Bar](screenshots/bottom_bar.png)  
*Persistent nav with FAB for quick actions.*

*(Note: Add actual screenshots to the `screenshots/` folder for better visuals!)*

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.7+)
- [Dart](https://dart.dev/get-dart) (included with Flutter)
- Android Studio or Xcode for emulation
- Git for cloning

### Installation
1. **Clone the Repository**:
   ```
   git clone https://github.com/yourusername/nexnote.git
   cd nexnote
   ```

2. **Install Dependencies**:
   ```
   flutter pub get
   ```

3. **Run the App**:
   - Connect a device or start an emulator.
   - Launch in debug mode:
     ```
     flutter run
     ```
   - For web: `flutter run -d chrome`
   - For specific platforms: `flutter run -d android` or `flutter run -d ios`

4. **Build for Release**:
   - Android: `flutter build apk`
   - iOS: `flutter build ios`
   - Web: `flutter build web`

### Project Structure
```
nexnote/
├── lib/
│   ├── main.dart          # App entry point
│   ├── pages/             # Screens: landing, login, signup, home, bottom_bar, side_bar
│   └── ...                # Other pages (notes, search, favorites)
├── assets/                # Images and resources
├── pubspec.yaml           # Dependencies (flutter, google_fonts, etc.)
└── README.md              # You're reading it!
```

## 🚀 Usage
1. Launch the app to the landing page.
2. Sign up or log in to access your dashboard.
3. Use the bottom bar to navigate between sections.
4. Tap the hamburger menu (top-left) for sidebar access to profile and settings.
5. Create, enhance, or compare notes—AI magic happens automatically!

Pro Tip: Customize the theme in `main.dart` or add real AI integrations via APIs like OpenAI for advanced features.

## 🤝 Contributing
Contributions are welcome! Here's how to get involved:
1. Fork the repo and create a feature branch (`git checkout -b feature/amazing-feature`).
2. Commit your changes (`git commit -m "Add amazing feature"`).
3. Push to the branch (`git push origin feature/amazing-feature`).
4. Open a Pull Request.

Please follow Flutter style guidelines and add tests where possible. Issues and feature requests are also appreciated!

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙌 Acknowledgments
- Built with ❤️ using Flutter.
- Icons from Material Design.
- Fonts powered by Google Fonts (Poppins).
- Inspired by modern productivity apps like Notion and Evernote.

## 📞 Support
Questions? Open an issue or reach out on [GitHub Discussions](https://github.com/yourusername/nexnote/discussions).

Happy Noting! 📝✨
