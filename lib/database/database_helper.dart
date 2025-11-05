import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('blackpearl.db');

    // Ensure sessions table exists (for existing databases)
    try {
      await _database!.execute('SELECT 1 FROM sessions LIMIT 1');
    } catch (e) {
      // Table doesn't exist, create it
      print('Sessions table not found, creating it...');
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          experiment_id INTEGER NOT NULL,
          session_number INTEGER NOT NULL,
          start_timestamp INTEGER NOT NULL,
          end_timestamp INTEGER,
          entry_count INTEGER NOT NULL DEFAULT 0,
          start_entry_id INTEGER,
          end_entry_id INTEGER,
          FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
          UNIQUE(experiment_id, session_number)
        )
      ''');
      await _database!.execute('''
        CREATE INDEX IF NOT EXISTS idx_sessions_experiment_id 
        ON sessions(experiment_id)
      ''');
    }

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version:
          3, // Increment version for experiment_id and session_id in data_entries
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      singleInstance: true, // Use single instance to avoid conflicts
    );

    // Enable foreign keys for CASCADE to work
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (e) {
      print('Warning: Could not enable foreign keys: $e');
    }

    // Set busy timeout to 5 seconds to handle locks gracefully
    // Use rawQuery for PRAGMA to avoid conflicts
    try {
      await db.rawQuery('PRAGMA busy_timeout=5000');
    } catch (e) {
      print('Warning: Could not set busy_timeout: $e');
    }

    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    // Create experiments table
    await db.execute('''
      CREATE TABLE experiments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create topics table
    await db.execute('''
      CREATE TABLE topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        experiment_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 0,
        sampling_rate REAL NOT NULL DEFAULT 1.0,
        FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
        UNIQUE(experiment_id, name)
      )
    ''');

    // Create data_entries table
    await db.execute('''
      CREATE TABLE data_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        topic_name TEXT NOT NULL,
        experiment_id INTEGER NOT NULL,
        session_id INTEGER,
        data TEXT NOT NULL,
        FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for efficient queries
    await db.execute('''
      CREATE INDEX idx_data_entries_experiment_topic 
      ON data_entries(experiment_id, topic_name, timestamp)
    ''');

    await db.execute('''
      CREATE INDEX idx_data_entries_session 
      ON data_entries(session_id, timestamp)
    ''');

    await db.execute('''
      CREATE INDEX idx_topics_experiment_id 
      ON topics(experiment_id)
    ''');

    // Create sessions table
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        experiment_id INTEGER NOT NULL,
        session_number INTEGER NOT NULL,
        start_timestamp INTEGER NOT NULL,
        end_timestamp INTEGER,
        entry_count INTEGER NOT NULL DEFAULT 0,
        start_entry_id INTEGER,
        end_entry_id INTEGER,
        FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
        UNIQUE(experiment_id, session_number)
      )
    ''');

    // Create index for sessions
    await db.execute('''
      CREATE INDEX idx_sessions_experiment_id 
      ON sessions(experiment_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2 && newVersion >= 2) {
      // Add sessions table for version 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          experiment_id INTEGER NOT NULL,
          session_number INTEGER NOT NULL,
          start_timestamp INTEGER NOT NULL,
          end_timestamp INTEGER,
          entry_count INTEGER NOT NULL DEFAULT 0,
          start_entry_id INTEGER,
          end_entry_id INTEGER,
          FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
          UNIQUE(experiment_id, session_number)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sessions_experiment_id 
        ON sessions(experiment_id)
      ''');
    }

    if (oldVersion < 3 && newVersion >= 3) {
      // Add experiment_id and session_id to data_entries for version 3
      try {
        // Check if columns exist
        final columns = await db.rawQuery('PRAGMA table_info(data_entries)');
        final columnNames = columns
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('experiment_id')) {
          await db.execute(
            'ALTER TABLE data_entries ADD COLUMN experiment_id INTEGER',
          );
          // Try to populate from topics (this is a best-effort migration)
          // For existing data without experiment_id, we'll need to handle it in queries
        }

        if (!columnNames.contains('session_id')) {
          await db.execute(
            'ALTER TABLE data_entries ADD COLUMN session_id INTEGER',
          );
        }

        // Recreate indexes
        try {
          await db.execute(
            'DROP INDEX IF EXISTS idx_data_entries_topic_timestamp',
          );
        } catch (e) {
          // Index might not exist
        }

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_data_entries_experiment_topic 
          ON data_entries(experiment_id, topic_name, timestamp)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_data_entries_session 
          ON data_entries(session_id, timestamp)
        ''');
      } catch (e) {
        print('Error during database migration to version 3: $e');
      }
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Helper method to get database path for export
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'blackpearl.db');
  }
}
