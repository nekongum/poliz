import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'emergency_alert_page.dart';

void main() => runApp(const GoodPolizApp());

class GoodPolizApp extends StatelessWidget {
  const GoodPolizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoodPoliz – Incident Importance Ranking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F172A), // slate-900-ish
        useMaterial3: true,
      ),
      home: const IncidentHomePage(),
    );
  }
}

class Incident {
  final String id;
  final String type;
  final String place;
  final DateTime time;
  final String notes;
  
  // =========================================================
  // ✨ NEW: รับค่า Score และ RankLevel ที่คำนวณจาก Backend โดยตรง
  // =========================================================
  final int score;
  final String rankLevel;

  Incident({
    required this.id,
    required this.type,
    required this.place,
    required this.time,
    required this.notes,
    required this.score,
    required this.rankLevel,
  });

  // Helper method for API call: แปลง Incident เป็น JSON Map ที่ Backend ต้องการ
  Map<String, dynamic> toJson() {
    // ไม่ต้องส่ง score และ rankLevel เพราะ Backend จะคำนวณเอง
    return {
      'type': type,
      'place': place,
      // ส่ง Local Time (ที่ผู้ใช้เลือก) ในรูปแบบ ISO 8601 String 
      'time': time.toIso8601String(), 
      'notes': notes,
    };
  }

  // Logic การแปลง JSON จาก Backend
  factory Incident.fromJson(Map<String, dynamic> json) {
    // Spring Boot ส่งกลับมาเป็น Local Date Time String
    DateTime parsedTime = DateTime.parse(json['time'] as String);

    return Incident(
      id: json['id']?.toString() ?? 'N/A', 
      type: json['type'] as String,
      place: json['place'] as String,
      time: parsedTime, 
      notes: json['notes'] as String,
      // รับค่าใหม่จาก Backend ที่คำนวณแล้ว
      score: json['score'] as int? ?? 0,
      rankLevel: json['rankLevel'] as String? ?? 'LOW',
    );
  }

  Incident copyWith({
    String? id,
    String? type,
    String? place,
    DateTime? time,
    String? notes,
    int? score,
    String? rankLevel,
  }) {
    return Incident(
      id: id ?? this.id,
      type: type ?? this.type,
      place: place ?? this.place,
      time: time ?? this.time,
      notes: notes ?? this.notes,
      score: score ?? this.score,
      rankLevel: rankLevel ?? this.rankLevel,
    );
  }
}

class RankBand {
  final String level;
  final Color color;
  final int score;

  const RankBand(this.level, this.color, this.score);
}

class IncidentHomePage extends StatefulWidget {
  const IncidentHomePage({super.key});

  @override
  State<IncidentHomePage> createState() => _IncidentHomePageState();
}

class _IncidentHomePageState extends State<IncidentHomePage> {
  // กำหนด Base URL ของ Spring Boot Backend
  static const String _hostIp = 'localhost'; 

  static const String _hostPort = '8080';
  static const String _baseUrl = 'http://$_hostIp:$_hostPort/api/v1/events';

  final List<Incident> _incidents = [];

  // สถานะสำหรับ Notification Badge (ตัวเลขสีแดง)
  int _newAlertCount = 0;

  // Cached rankings (id -> score) ถูกแทนที่ด้วย incident.score โดยตรง
  final Map<String, int> _ranked = {};
  DateTime? _lastRun;

  // Controls
  final _placeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _type = 'Traffic Accident';
  DateTime _pickedTime = DateTime.now();
  final _types = const <String>[
    'Traffic Accident',
    'Medical Emergency',
    'Fire',
    'Armed Robbery',
    'Violent Crime',
    'Disturbance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadIncidents(); // โหลดข้อมูลเหตุการณ์ครั้งแรก
    _getNewAlertCount(); // ดึงจำนวนแจ้งเตือนครั้งแรก
    _applyRanking();
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- API Functions ---

  // 1. ดึงรายการเหตุการณ์ทั้งหมดจาก Backend
  Future<void> _loadIncidents() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        setState(() {
          // โหลดข้อมูลทั้งหมดจาก Backend มา
          _incidents.clear();
          _incidents.addAll(jsonList.map((json) => Incident.fromJson(json)).toList());
          _applyRanking(); // รัน Ranking (ตอนนี้แค่แคชคะแนน) หลังโหลดเสร็จ
        });
      } else {
        print('Failed to load incidents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error connecting to backend: $e');
    }
  }

  // 2. ดึงจำนวนแจ้งเตือนใหม่ (สำหรับ Badge)
  Future<void> _getNewAlertCount() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/new/count'));
      if (response.statusCode == 200) {
        final int count = int.parse(response.body);
        setState(() {
          _newAlertCount = count;
        });
      }
    } catch (e) {
      print('Error fetching new alert count: $e');
    }
  }

  // 3. ทำเครื่องหมายว่าอ่านแล้ว (เมื่อผู้ใช้กดดูแจ้งเตือน)
  Future<void> _markAllAsRead() async {
    try {
      await http.post(Uri.parse('$_baseUrl/mark-as-read'));
      _getNewAlertCount(); // อัปเดต Badge ให้เป็น 0
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // --- **ลบ Logic** และใช้ค่าจาก Model โดยตรง ---
  // ฟังก์ชันนี้ถูกลดความซับซ้อนลงเหลือเพียงการคืนค่า score ที่โหลดมา
  int _scoreFor(Incident i) {
    return i.score;
  }
  
  // ฟังก์ชันนี้ใช้ rankLevel ในการกำหนดสีเท่านั้น
  RankBand _bandFor(int score, String rankLevel) {
    Color color;
    switch (rankLevel) {
      case 'CRITICAL':
        color = Colors.red.shade600;
        break;
      case 'HIGH':
        color = Colors.orange.shade600;
        break;
      case 'MEDIUM':
        color = Colors.amber.shade600;
        break;
      case 'LOW':
      default:
        color = Colors.green.shade600;
        break;
    }
    return RankBand(rankLevel, color, score);
  }
  // -------------------------------------------------------------

  void _applyRanking() {
    _ranked
      ..clear();
    for (final i in _incidents) {
      // แคชคะแนนที่คำนวณจาก Backend
      _ranked[i.id] = i.score; 
    }
    _lastRun = DateTime.now();
    setState(() {});
  }

  List<Incident> _viewIncidents() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _incidents
        .where((i) {
      if (q.isEmpty) return true;
      return [i.id, i.type, i.place, i.notes]
          .any((f) => f.toLowerCase().contains(q));
    })
        .toList();

    // เรียงตาม score ที่คำนวณจาก Backend โดยตรง (a.score)
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  String _fmtDateTime(DateTime t) {
    // ⚠️ ใช้ t โดยตรงเพราะเป็นเวลา Local ที่ถูกต้อง
    final local = t; 
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _newId() {
    final r = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _pickedTime,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickedTime),
    );
    if (t == null) return;

    setState(() {
      _pickedTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  // 4. แก้ไข: เปลี่ยนจากการเพิ่มลง List ภายใน เป็นการ POST ไป Backend
  void _addIncident() async {
    if (_placeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place is required')),
      );
      return;
    }

    // 1. สร้าง Incident Object ที่จะส่งไป Backend
    final newIncident = Incident(
      id: _newId(), // ID นี้จะถูก Backend ทิ้งไป แต่เราเก็บไว้ใน Flutter ก่อน
      type: _type,
      place: _placeCtrl.text.trim(),
      // ถูกต้อง: _pickedTime เป็น Local Time อยู่แล้ว ปล่อยให้ toJson() จัดการแปลงเป็น Local time string เอง
      time: _pickedTime, 
      notes: _notesCtrl.text.trim(),
      // ค่าเหล่านี้จะไม่ถูกใช้ในการส่งไป Backend แต่ถูกบังคับใน constructor
      score: 0,
      rankLevel: 'LOW',
    );

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newIncident.toJson()), // แปลงเป็น JSON ก่อนส่ง
      );

      if (response.statusCode == 200) {
        // สำเร็จ: Backend บันทึกข้อมูลแล้ว
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident added successfully (via Backend)!')),
        );

        // 2. โหลดข้อมูลทั้งหมดจาก Backend ใหม่ เพื่อให้ List อัปเดต
        _loadIncidents(); 

        // 3. ดึงจำนวนแจ้งเตือนใหม่ เพื่ออัปเดต Badge ทันที
        _getNewAlertCount(); 

        // 4. ล้างฟอร์ม
        _placeCtrl.clear();
        _notesCtrl.clear();

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add incident. Status: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e')),
      );
    }

    // ล้างฟอร์มและอัปเดต UI (setState ถูกเรียกใน _loadIncidents แล้ว)
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    final list = _viewIncidents();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GoodPoliz: Incident Importance Ranking',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // 🎯 แก้ไข: เปลี่ยนเป็น Icons.wifi_tethering เพื่อให้คล้ายกับรูปที่ให้มา
          IconButton(
            tooltip: 'Show Broadcast Status', // เปลี่ยน tooltip ตามไอคอนใหม่
            onPressed: _applyRanking, // ยังคงผูกกับฟังก์ชัน AI Ranking เดิม
            icon: Icon(Icons.wifi_tethering, color: Theme.of(context).colorScheme.primary),
          ),
          // 5. เพิ่ม Notification Badge
          Stack(
            children: [
              IconButton(
                tooltip: 'Emergency Alerts',
                icon: const Icon(Icons.emergency_outlined, color: Colors.redAccent),
                onPressed: () {
                  // เมื่อกดปุ่ม ให้ Mark All As Read ก่อนเข้าหน้า Alerts
                  _markAllAsRead(); 
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencyAlertPage()),
                  );
                },
              ),
              if (_newAlertCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_newAlertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: isWide
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildListCard(list)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _buildFormCard(context),
                      const SizedBox(height: 12),
                      _buildHelpCard(),
                    ],
                  ),
                ),
              ],
            )
                : ListView(
              children: [
                _buildListCard(list),
                const SizedBox(height: 12),
                _buildFormCard(context),
                const SizedBox(height: 12),
                _buildHelpCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildListCard(List<Incident> list) {
    // ... (ส่วนโค้ด List Card เดิม) ...
    return Card(
      elevation: 1,

      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Header + search (fixed to be responsive)
            Row(
              children: [
                const Icon(Icons.emergency_outlined),
                const SizedBox(width: 5),
                // Title takes less room
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Incident List',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Search gets more room
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      //prefixIcon: Icon(Icons.search),
                      hintText: 'Search by id, type, place, notes…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No incidents found (or Backend disconnected).',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              // **FIX: เปลี่ยนจาก Flexible/ListView.builder ซ้อนกันใน Column 
              // ให้เป็น Expanded/ListView.builder เพื่อใช้พื้นที่ว่างที่เหลือ**
              Expanded(
                child: ListView.builder(
                  // ลบ shrinkWrap และ NeverScrollableScrollPhysics ออก เพราะตอนนี้มันคือ ListView หลัก
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    return _buildIncidentTile(list[index]);
                  },
                ),
              ),
              
            const SizedBox(height: 8),

            // Footer status (no overflow now)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Loaded ${list.length} incidents from Backend.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastRun == null
                        ? ''
                        : 'Last AI run: ${_fmtDateTime(_lastRun!)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTile(Incident i) {
    // ⚠️ ใช้ค่า score และ rankLevel ที่โหลดมาตรงๆ
    final score = i.score;
    final rankLevel = i.rankLevel;
    final band = _bandFor(score, rankLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(Icons.warning_amber_rounded, color: Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      '#${i.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Chip(
                      label: Text(
                        i.type,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _iconText(Icons.place_outlined, i.place),
                    _iconText(Icons.schedule, _fmtDateTime(i.time)),
                  ],
                ),
                if (i.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2.0, right: 6),
                        child: Icon(Icons.notes_outlined, size: 18),
                      ),
                      Expanded(
                        child: Text(
                          i.notes,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: score / 100.0,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE5E7EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: band.color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  band.level,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${band.score}%',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    // ... (ส่วนโค้ด Form Card เดิม) ...
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.add_circle_outline),
                SizedBox(width: 8),
                Text(
                  'Add New Incident',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _placeCtrl,
              decoration: const InputDecoration(
                labelText: 'Place',
                hintText: 'e.g., Rama IX Rd, near Central Plaza',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(_fmtDateTime(_pickedTime)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _pickDateTime(context),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Pick'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText:
                'Details that help AI judge severity (e.g., weapon, injuries, fire, number of people)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(Icons.error_outline, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Importance is AI-estimated (simulated). Always verify on dispatch.',
                          style:
                          TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addIncident,
                  icon: const Icon(Icons.star_border),
                  label: const Text('Add & Rank'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    // ... (ส่วนโค้ด Help Card เดิม) ...
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: const [
            Row(
              children: [
                Icon(Icons.menu_book_outlined),
                SizedBox(width: 8),
                Text(
                  'How it works',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('1) Add incident with type, place, time, notes.'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '2) AI computes an importance score (0–100) and a level (LOW / MEDIUM / HIGH / CRITICAL).'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('3) List is sorted with highest priority on top.'),
            ),
            SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This is a front-end demo. Data is now saved to and loaded from your Spring Boot backend.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
