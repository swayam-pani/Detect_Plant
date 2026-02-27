import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('plant_detection.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const boolType =
        'INTEGER NOT NULL'; // SQLite handles boolean as integer (0/1)

    // Table: Scans
    await db.execute('''
    CREATE TABLE scans (
      id $idType,
      imagePath $textType,
      plantDetected $textType,
      diseaseDetected $textNullable,
      diseaseConfidence $textNullable,
      isHealthy $boolType,
      scanDate $textType
    )
    ''');

    // Table: Complaints
    await db.execute('''
    CREATE TABLE complaints (
      id $idType,
      scanId INTEGER,
      reason $textType,
      date $textType,
      FOREIGN KEY (scanId) REFERENCES scans (id)
    )
    ''');
  }

  // --- Scan Methods ---

  Future<int> insertScan(Map<String, dynamic> scan) async {
    final db = await instance.database;
    return await db.insert('scans', scan);
  }

  Future<List<Map<String, dynamic>>> getAllScans() async {
    final db = await instance.database;
    return await db.query('scans', orderBy: 'scanDate DESC');
  }

  Future<int> deleteScan(int id) async {
    final db = await instance.database;
    return await db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  // --- Complaint Methods ---

  Future<int> insertComplaint(Map<String, dynamic> complaint) async {
    final db = await instance.database;
    return await db.insert('complaints', complaint);
  }

  Future<List<Map<String, dynamic>>> getAllComplaints() async {
    final db = await instance.database;
    return await db.query('complaints', orderBy: 'date DESC');
  }
}
