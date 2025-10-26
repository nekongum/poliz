import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// ต้อง import Incident และ RankBand Class จาก main.dart เพื่อใช้ Data Model
import 'main.dart'; 

// ====================================================================
// FIX: ลบคลาส IncidentRanker ออกไปทั้งหมด เพราะ Logic อยู่ที่ Backend แล้ว
// ====================================================================

class EmergencyAlertPage extends StatefulWidget {
  const EmergencyAlertPage({super.key});

  @override
  State<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends State<EmergencyAlertPage> {
  // กำหนด Base URL ของ Spring Boot Backend
  static const String _baseUrl = 'http://localhost:8080/api/v1/events'; 

  List<Incident> _loadedIncidents = [];
  bool _isLoading = true;

  // final _incidentRanker = IncidentRanker(); // <== ถูกลบออกไป

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }
  
  @override
  void dispose() {
    // ไม่มี Controller ที่ต้อง dispose ในหน้านี้
    super.dispose();
  }

  // 1. ฟังก์ชันโหลดข้อมูลจาก Backend
  Future<void> _loadAlerts() async {
    if (!mounted) return; 

    setState(() {
      _isLoading = true;
    });
    
    try {
      // NOTE: ดึงข้อมูลทั้งหมดจาก Backend
      final response = await http.get(Uri.parse(_baseUrl));

      if (!mounted) return; 
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        
        // แปลง JSON เป็น List<Incident>
        _loadedIncidents = jsonList.map((json) => Incident.fromJson(json)).toList();

        // FIX: จัดเรียงข้อมูลตามความสำคัญ (สูงสุดไปต่ำสุด) โดยใช้ค่า score จาก Backend โดยตรง
        _loadedIncidents.sort((a, b) {
          return b.score.compareTo(a.score); // เรียงจากมากไปน้อย
        });

      } else {
        print('Failed to load alerts: ${response.statusCode}');
        _loadedIncidents = []; 
      }
    } catch (e) {
      print('Error connecting to backend: $e');
      _loadedIncidents = [];
    } finally {
      if (!mounted) return; 
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper function เพื่อแปลง DateTime เป็น String แบบง่ายๆ สำหรับ List Tile
  String _timeAgo(DateTime time) {
    // time เป็น Local Time อยู่แล้วจาก Incident.fromJson
    final diff = DateTime.now().difference(time); 
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  // Helper function เพื่อดึงสีและระดับจาก Model ที่โหลดมาจาก Backend
  Map<String, dynamic> _getRankInfo(Incident i) {
    // ⚠️ ไม่ต้องคำนวณคะแนนแล้ว ใช้ rankLevel มากำหนดสีโดยตรง
    Color color;
    switch (i.rankLevel) {
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

    return {
      'title': i.type,
      'location': i.place,
      'time': _timeAgo(i.time),
      'level': i.rankLevel, 
      'color': color,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Alerts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // เพิ่มปุ่ม Refresh สำหรับดึงข้อมูลล่าสุด
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadedIncidents.isEmpty
              ? const Center(
                  child: Text('No incidents found from backend.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _loadedIncidents.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, i) {
                    final incident = _loadedIncidents[i];
                    // 2. ใช้ _getRankInfo เพื่อดึงข้อมูลสีและระดับมาแสดงผล UI
                    final a = _getRankInfo(incident); 
                    
                    return Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: a['color'].withOpacity(0.8),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.emergency, color: a['color'], size: 30),
                        title: Text(
                          // 3. แสดง Type/Title จากข้อมูล Backend
                          a['title'], 
                          style: TextStyle(fontWeight: FontWeight.w700, color: a['color']),
                        ),
                        subtitle: Text(
                          // 4. แสดง Location และ Time จากข้อมูล Backend
                          '#${incident.id} • ${a['location']} • ${a['time']}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        trailing: Text(
                          // 5. แสดง Level จาก Backend
                          a['level'],
                          style: TextStyle(
                            color: a['color'],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
