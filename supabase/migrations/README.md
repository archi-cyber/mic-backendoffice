# Church Management System

> **Documentation**
> - [Full documentation (English)](docs/DOCUMENTATION.md)
> - [Documentation complète (Français)](docs/DOCUMENTATION.fr.md)
> - [User guide (English)](docs/USER_GUIDE.md)
> - [Guide utilisateur (Français)](docs/USER_GUIDE.fr.md)

A comprehensive Flutter application for managing church operations including member management, attendance tracking, giving, ministries, events, follow-ups, and analytics.

## Features

### Core Modules

- **Member Management** - Complete member profiles, search, and management
- **Attendance Tracking** - Track attendance for services, cell groups, departments, and events
- **Giving Management** - Track tithes, offerings, pledges, and donations
- **Ministries & Departments** - Organize and manage church departments and ministries
- **Events & Activities** - Plan and track church events
- **Follow-up & Tasks** - Assign and track follow-up tasks
- **Reporting & Analytics** - Comprehensive reports and insights
- **Offline Support** - Full offline data entry with automatic sync
- **Role-Based Access Control** - Granular permissions for different user roles

### User Roles & Permissions

1. **Super Admin / Pastor**
   - Full access to all features
   - Can manage all users and branches
   - Access to all reports and analytics

2. **Branch Admin**
   - Full access within their branch
   - Can manage members, attendance, giving
   - Can manage ministries and events
   - Access to branch-specific reports

3. **Department Leader**
   - Access to department-specific data
   - Can manage attendance and events
   - Can view and assign follow-ups
   - Access to department reports

4. **Follow-up Leader**
   - Can view attendance
   - Can manage follow-ups and tasks
   - Can assign tasks to others

5. **Standard Member** (Read-only)
   - View-only access to their own data
   - Can view events and ministries

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Supabase account
- Android Studio / Xcode (for mobile development)
- VS Code or Android Studio (for development)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mic_backoffice
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a Supabase project at https://supabase.com
   - Get your project URL and anon key
   - Update `lib/config/app_config.dart` with your credentials:
     ```dart
     static const String supabaseUrl = 'YOUR_SUPABASE_URL';
     static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     ```

4. **Set up Supabase Database**
   - See `DATABASE_SCHEMA.md` for complete database schema
   - Run the SQL scripts in Supabase SQL Editor to create tables
   - Enable Row Level Security (RLS) policies as documented

5. **Generate code**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── config/           # App configuration
├── controllers/      # Business logic controllers
├── models/          # Data models
├── pages/           # UI screens
│   ├── auth/       # Authentication pages
│   ├── home/       # Dashboard
│   ├── members/    # Member management
│   ├── attendance/ # Attendance tracking
│   ├── giving/     # Giving management
│   ├── ministries/ # Ministries & departments
│   ├── events/     # Events management
│   ├── followups/  # Follow-ups & tasks
│   ├── reports/    # Reports & analytics
│   └── settings/   # Settings
├── providers/       # State management (Provider)
├── repositories/    # Data access layer
├── services/        # Services (Supabase, offline storage, sync)
├── translation/     # Localization files
└── utils/          # Utilities (permissions, helpers)
```

## Key Technologies

- **Flutter** - Cross-platform UI framework
- **Supabase** - Backend as a Service (auth, database, storage)
- **Provider** - State management
- **SQLite (sqflite)** - Offline storage
- **Connectivity Plus** - Network connectivity detection
- **FL Chart** - Charts and analytics visualization

## Offline Support

The app supports full offline functionality:

- Data entry works offline
- All changes are queued locally
- Automatic sync when connection is restored
- Manual sync option available

Offline data is stored in SQLite database and synced to Supabase when online.

## Permission System

Permissions are defined in `lib/utils/permissions.dart`. Each role has specific permissions:

- **View permissions** - What data can be viewed
- **Manage permissions** - What data can be created/edited/deleted
- **Scope restrictions** - Branch/department-level restrictions

## Database Schema

See `DATABASE_SCHEMA.md` for complete database schema documentation including:

- Table structures
- Relationships
- Row Level Security policies
- Indexes and constraints

## Development

### Running Tests
```bash
flutter test
```

### Code Generation
Whenever you modify models with `@JsonSerializable()`, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Building for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is private and proprietary.

## Support

For issues and questions, please contact the development team.

## Roadmap

- [ ] Complete member management UI
- [ ] Attendance entry screens
- [ ] Giving entry forms
- [ ] Event management UI
- [ ] Follow-up task management
- [ ] Advanced reporting dashboard
- [ ] Push notifications
- [ ] Multi-language support
- [ ] Advanced search and filtering
- [ ] Export functionality (PDF, Excel)
