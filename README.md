# 🧠 Spark - Cognitive Training App

**Advanced cognitive training platform for athletes and fitness enthusiasts**

Spark is a cutting-edge mobile application designed to enhance cognitive performance through targeted brain training exercises. Built with Flutter and Firebase, it offers personalized training programs, real-time performance tracking, and a comprehensive suite of cognitive drills.

## ✨ Features

### 🎯 **Core Training**
- **Custom Drills** - Create personalized cognitive training exercises
- **Training Programs** - Structured multi-day training regimens
- **Real-time Performance** - Live feedback and scoring
- **Progress Tracking** - Detailed analytics and improvement metrics

### 🔐 **Privacy & Sharing**
- **Private by Default** - All content starts private to the creator
- **Selective Sharing** - Choose what to make public to the community
- **User-wise Content** - Each user has their own private workspace
- **Community Discovery** - Explore public content from other users

### 🏃‍♂️ **Sport-Specific Training**
- **Multi-Sport Support** - Soccer, Basketball, Tennis, Hockey, and more
- **Difficulty Levels** - Beginner to Expert progression
- **Customizable Parameters** - Duration, intensity, and complexity settings

### 📱 **Modern UI/UX**
- **Responsive Design** - Optimized for all screen sizes
- **Dark/Light Themes** - System-adaptive theming
- **Intuitive Navigation** - Clean, user-friendly interface

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.16.0)
- Dart SDK (>=3.0.0)
- Firebase project setup
- iOS/Android development environment

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd spark_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart` with your configuration

4. **Run the app**
   ```bash
   flutter run
   ```

## 🏗️ Architecture

### **Clean Architecture**
- **Domain Layer** - Business logic and entities
- **Data Layer** - Repositories and data sources
- **Presentation Layer** - UI components and state management

### **State Management**
- **BLoC Pattern** - Predictable state management
- **Dependency Injection** - GetIt for service location
- **Repository Pattern** - Abstracted data access

### **Backend Services**
- **Firebase Auth** - User authentication
- **Firestore** - Real-time database
- **Cloud Storage** - File storage (if needed)

## 📁 Project Structure

```
lib/
├── core/                   # Core functionality
│   ├── auth/              # Authentication wrapper
│   ├── di/                # Dependency injection
│   ├── router/            # App routing
│   ├── storage/           # Local storage
│   └── theme/             # App theming
├── features/              # Feature modules
│   ├── auth/              # Authentication
│   ├── drills/            # Drill management
│   ├── programs/          # Training programs
│   ├── sharing/           # Content sharing
│   ├── profile/           # User profiles
│   └── stats/             # Performance analytics
└── main.dart              # App entry point
```

## 🔧 Configuration

### **Environment Setup**
- Development and production configurations
- Firebase project separation
- API endpoint management

### **Build Variants**
```bash
# Development build
flutter run --flavor dev

# Production build
flutter build apk --release
flutter build ios --release
```

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Generate coverage report
flutter test --coverage
```

## 📦 Deployment

### **Android**
```bash
flutter build appbundle --release
```

### **iOS**
```bash
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For support and questions, please contact the development team.

---

**Built with ❤️ using Flutter & Firebase**
