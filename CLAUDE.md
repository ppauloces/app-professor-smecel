# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter mobile application for school attendance tracking (SMECEL - Sistema Municipal de Educação). The app allows teachers to record student attendance offline and sync with a remote server when online. The app supports Portuguese localization (pt_BR).

**Key Technologies:**
- Flutter SDK 3.0+
- SQLite (sqflite) for local database
- Provider for state management
- HTTP for API communication
- Connectivity Plus for network status

## Development Commands

### Running the App
```bash
flutter run
```

### Testing
```bash
flutter test
```

### Build
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

### Code Analysis
```bash
flutter analyze
```

### Get Dependencies
```bash
flutter pub get
```

## Architecture

### Offline-First Pattern

The app follows an **offline-first architecture** where:

1. **Login triggers full sync**: When a teacher logs in, [lib/providers/auth_provider.dart](lib/providers/auth_provider.dart) calls `FullSyncService.syncAllData()` to download all schools, classes (turmas), and schedules (horários) to local SQLite database
2. **Local-first operations**: All read operations prioritize SQLite cache over API calls
3. **Background sync**: Modified data (attendance records) are marked as `sincronizado = 0` and synced when connectivity is available

### Database Schema

The SQLite database ([lib/database/database_helper.dart](lib/database/database_helper.dart)) has these main tables:

- `professores` - Teacher accounts
- `escolas` - Schools assigned to teachers
- `turmas` - Classes/grades (turmas) within schools
- `horarios` - Class schedules (day of week + period number)
- `alunos` - Students enrolled in classes
- `aulas` - Individual lesson instances (date + class)
- `frequencias` - Attendance records (student + lesson + present/absent)

**Important**: All tables have a `sincronizado` flag (0 = pending sync, 1 = synced) and foreign key relationships.

### State Management

Uses **Provider** pattern with these main providers:

- `AuthProvider` ([lib/providers/auth_provider.dart](lib/providers/auth_provider.dart)) - Authentication state and full sync orchestration
- `FrequenciaProvider` ([lib/providers/frequencia_provider.dart](lib/providers/frequencia_provider.dart)) - Attendance state management
- `SyncProvider` ([lib/providers/sync_provider.dart](lib/providers/sync_provider.dart)) - Background sync coordination

### Service Layer

Services handle business logic and API communication:

- `AuthService` - Login/logout, stores teacher credentials in SharedPreferences
- `FullSyncService` - Downloads complete dataset on login (schools → turmas → horários for each turma)
- `EscolaService`, `TurmaService`, `HorarioService` - CRUD operations with cache-first pattern
- `FrequenciaService` - Attendance record management
- `NovaFrequenciaService` - New attendance workflow
- `SyncService` - Background sync of pending records

### API Integration

Base URL: `https://smecel.com.br/api/professor`

The `/endpoints` directory contains PHP backend files that show the API contract:
- `login.php` - Authentication
- `get_escolas.php` - List schools for teacher
- `get_turmas.php` - List classes for school
- `get_horarios.php` - Get schedule for specific date
- `salvar_frequencia.php` - Submit attendance records

**Note**: Services expect responses with `{"status": "success", "data": {...}}` format. API may return both List and Map formats for collections.

### Navigation Flow

1. `AuthWrapper` → checks auth state
2. Authenticated: `EscolasScreen` (select school)
3. `TurmasScreen` (select class/turma)
4. `SelecionarDataScreen` (select date)
5. `SelecionarHorarioScreen` (select time slot from schedule)
6. `NovaChamadaScreen` (record attendance for all students)

## Important Implementation Details

### Full Sync Process

In [lib/services/full_sync_service.dart](lib/services/full_sync_service.dart):

1. Downloads all schools for the teacher
2. For each school, downloads all classes (turmas)
3. For each class, downloads ALL schedules by iterating through weekdays 1-6 (Monday-Saturday)
4. Uses fictitious dates to query `get_horarios.php` for each weekday

This ensures the app works completely offline after initial login.

### Cache-First Pattern

Services like `EscolaService` follow this pattern:
```dart
1. Check local cache with DatabaseHelper.getXxxCached()
2. If cache exists, return immediately
3. If empty or force refresh, call API
4. Save API response to local database
5. Return data
```

### HTTP Overrides

[lib/utils/http_overrides.dart](lib/utils/http_overrides.dart) implements custom certificate validation - likely for development/testing with self-signed certificates.

### Database Versioning

Current database version is 2. The `onUpgrade` method in DatabaseHelper drops all tables and recreates them on version changes. **Warning**: This causes data loss on schema changes.

### Models

All models in [lib/models/](lib/models/) follow a consistent pattern:
- `fromMap(Map<String, dynamic>)` constructor for database/JSON deserialization
- `toMap()` method for database/JSON serialization
- `copyWith()` for immutable updates

## Common Patterns

### Adding a New Screen

1. Create screen file in `lib/screens/`
2. Use `Consumer<Provider>` or `Provider.of<Provider>(context)` to access state
3. Call service methods through providers when possible
4. Handle loading states with `CircularProgressIndicator`

### Adding a New Model

1. Create model in `lib/models/`
2. Add table creation SQL in `DatabaseHelper._onCreate()`
3. Add CRUD methods in `DatabaseHelper`
4. Create corresponding service in `lib/services/`
5. Update sync logic if needed

### Working with Dates

The app uses:
- `DateTime` for internal operations
- ISO 8601 strings for database storage (`toIso8601String()`)
- `YYYY-MM-DD` format for API calls
- `intl` package for locale-specific formatting (Portuguese)

### Weekday Convention

The app uses 1-6 for weekdays (1=Monday, 6=Saturday), matching the backend convention. This differs from Dart's `DateTime.weekday` which uses 1-7 (1=Monday, 7=Sunday).

## Testing

The project has minimal test coverage. The only test file is [test/widget_test.dart](test/widget_test.dart) which contains a basic widget test.

## Known Issues

1. Database schema changes cause complete data loss (version upgrade drops all tables)
2. `SyncService._baseUrl` points to a simulated URL, not the real SMECEL API
3. No error recovery if full sync fails during login
4. `DevHttpOverrides` disables certificate validation globally (security concern for production)
