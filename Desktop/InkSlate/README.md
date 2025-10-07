# InkSlate - Personal Productivity App

A minimalist, modern iOS app designed to help you organize your life with a clean, intuitive interface. InkSlate combines multiple productivity tools into one cohesive experience.

## ✨ Features

### 🏠 **Homescreen**
- **Minimalist Design**: Clean, distraction-free interface
- **Live Time & Date**: Real-time display with elegant typography
- **Modern Aesthetics**: White background with carefully chosen fonts and spacing

### 📝 **Notes**
- **Rich Text Editing**: Full text formatting with bullet points, indentation, and styling
- **Password Protection**: Secure your sensitive notes with optional password protection
- **Folder Organization**: Organize notes into custom folders for better structure
- **Search Functionality**: Find notes quickly with real-time search
- **Trash Management**: Safely delete and restore notes with trash system
- **Organized Storage**: All notes stored locally with SwiftData
- **Clean Interface**: Simple, focused writing experience
- **CloudKit Sync**: Automatic synchronization across all your Apple devices

### 💭 **Quotes**
- **Inspiration Collection**: Save and organize meaningful quotes
- **Category System**: Organize quotes by Motivation, Wisdom, Love, Success, Life, Humor, Inspiration, Philosophy, and Custom
- **Beautiful Display**: Modern card-based interface for quote browsing
- **Easy Management**: Add, edit, and categorize quotes effortlessly

### 🍳 **Recipes**
- **Recipe Collection**: Store and organize your favorite recipes
- **Ingredient Management**: Track ingredients, spices, and shopping lists
- **Category Organization**: Breakfast, Lunch, Dinner, Snack, Dessert, Beverage, Appetizer, and Custom categories
- **Kitchen Integration**: Fridge items, spice rack, and shopping cart management

### 🗺️ **Places**
- **Location Tracking**: Save and organize important places with detailed information
- **Category Management**: Organize places by custom categories (restaurants, activities, etc.)
- **Rich Details**: Store addresses, ratings, photos, visit dates, and personal notes
- **Comprehensive Rating System**: Rate places on multiple criteria (overall, price, quality, atmosphere, fun factor, scenery)
- **Visit Tracking**: Keep track of when you visited and whether you'd return
- **Photo Support**: Add photos to remember your experiences
- **Food Type & Timing**: Track food types and best times to visit
- **Modern UI**: Clean, minimalist interface with black and grey color scheme
- **CloudKit Sync**: Automatic synchronization across all your Apple devices

### 📺 **Watchlist**
- **Entertainment Tracking**: Manage movies, shows, and content to watch
- **TMDB Integration**: Connect with The Movie Database for rich content information
- **Live Search**: Real-time search through thousands of movies and TV shows
- **Popular Content**: Browse trending movies and TV shows in horizontal scrollable format
- **Favorites System**: Mark content as favorites and create custom lists
- **Detailed Information**: View ratings, descriptions, cast, and more with optimized layouts
- **Personal Ratings**: Rate content you've watched
- **Star Button**: Add/remove items from watchlist directly from detail views
- **List View**: Clean list interface for managing your watchlist
- **CloudKit Sync**: Automatic synchronization across all your Apple devices

### 🧠 **Mind Maps**
- **Visual Thinking**: Create and organize mind maps for brainstorming
- **Flexible Structure**: Adapt to your thinking process and ideas

### 📊 **Journal**
- **Daily Journaling**: Create and maintain daily journal entries with streak tracking
- **Writing Prompts**: Get inspiration with categorized prompts (Personal Growth, Relationships, Creative, Reflection, Gratitude, Planning)
- **Prompt Categories**: Browse and select specific prompts from each category
- **Rich Text Editing**: Full text formatting with bullet points, indentation, and styling
- **Word Count**: Live word counting for your entries
- **Streak Tracking**: Visual streak counter to motivate daily writing (current and longest streaks)
- **Multiple Journals**: Create different journals for different purposes
- **Daily Journal Pinned**: Default daily journal always appears at the top
- **Date Editing**: Edit entry dates with intuitive date picker
- **CloudKit Sync**: Automatic synchronization across all your Apple devices

### ⚙️ **Settings & Profile**
- **Customization**: Personalize your app experience
- **User Profile**: Manage your account and preferences

## 🎨 **Design System**

Slate features a comprehensive design system that ensures consistency across all features:

- **Minimalist Color Palette**: Clean whites, subtle grays, and accent colors
- **Typography**: Carefully chosen fonts for optimal readability
- **Spacing**: Consistent spacing system for visual harmony
- **Components**: Reusable UI components for a cohesive experience
- **Animations**: Subtle, purposeful animations that enhance usability

## 🛠️ **Technical Features**

- **SwiftUI**: Built with Apple's modern declarative UI framework
- **SwiftData**: Local data persistence with Apple's latest data framework
- **CloudKit Integration**: Seamless data synchronization across Apple devices
- **iOS 18.5+**: Optimized for the latest iOS features
- **Real-time Updates**: Live time display and dynamic content
- **Responsive Design**: Adapts to different screen sizes and orientations
- **TMDB API**: Integration with The Movie Database for entertainment content
- **Rich Text Support**: Full text formatting and editing capabilities
- **Photo Integration**: Native photo picker and storage
- **Security**: Optional password protection for sensitive content
- **Search Debouncing**: Optimized search performance with debounced input
- **Async Image Loading**: Efficient image loading and caching
- **Modern UI Components**: Custom components with consistent design system
- **Data Models**: Comprehensive SwiftData models for all features

## 📱 **Screenshots**

*Screenshots coming soon - showcasing the clean interface and key features*

## 🚀 **Getting Started**

### Prerequisites
- Xcode 16.0 or later
- iOS 18.5 or later
- macOS 14.0 or later (for development)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/slate.git
   cd slate
   ```

2. Open the project in Xcode:
   ```bash
   open InkSlate.xcodeproj
   ```

3. Build and run on the iOS Simulator or your device

### Usage
1. **First Launch**: The app opens to a clean homescreen with time and date
2. **Navigation**: Use the hamburger menu to access different features
3. **Adding Content**: Each feature has intuitive add buttons for creating new items
4. **Organization**: Use categories and tags to keep your content organized

## 🏗️ **Architecture**

The app follows a clean, modular architecture:

```
InkSlate/
├── Core/                    # App core functionality
│   ├── InkSlateApp.swift  # App entry point
│   ├── ContentView.swift   # Main content coordinator
│   ├── DesignSystem.swift  # Design system definitions
│   ├── LoadingStateManager.swift
│   ├── CloudKitConfiguration.swift
│   └── SharedStateManager.swift
├── Models/                 # Data models
│   ├── NotesModels.swift
│   ├── QuotesModels.swift
│   ├── RecipeModels.swift
│   ├── PlacesModels.swift
│   ├── WatchlistModels.swift
│   ├── JournalModels.swift
│   ├── JournalPromptModels.swift
│   ├── MindMapModels.swift
│   └── TodoModels.swift
├── Views/                  # SwiftUI views
│   ├── Items/             # Homescreen
│   ├── Notes/             # Notes feature
│   ├── Quotes/             # Quotes collection
│   ├── Recipes/           # Recipe management
│   ├── Places/            # Location tracking
│   ├── Watchlist/         # Entertainment tracking
│   ├── MindMaps/          # Mind mapping
│   ├── Journal/           # Journaling
│   ├── Navigation/        # Navigation components
│   ├── Settings/          # App settings
│   └── Profile/           # User profile
└── Services/              # External services
    └── TMDBService.swift  # Movie database integration
```

## 🤝 **Contributing**

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines
- Follow SwiftUI best practices
- Maintain the minimalist design aesthetic
- Write clean, documented code
- Test on multiple device sizes
- Ensure accessibility compliance

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- Built with SwiftUI and SwiftData
- Icons from SF Symbols
- Design inspired by modern minimalist principles
- Thanks to the open-source community for inspiration and tools

## 📞 **Support**

If you encounter any issues or have questions, please:
1. Check the existing issues on GitHub
2. Create a new issue with detailed information
3. Contact the development team

---

**InkSlate** - Organize your life, one feature at a time. ✨
