package com.example.demo.service;

import com.example.demo.model.Incident;
import com.example.demo.repository.IncidentRepository;
import org.springframework.stereotype.Service;
import java.util.List;
import java.time.LocalDateTime;

@Service
public class IncidentService {

    private final IncidentRepository repository;

    // กำหนดค่าเกณฑ์คะแนน (Thresholds)
    private static final int CRITICAL_THRESHOLD = 85;
    private static final int HIGH_THRESHOLD = 70;
    private static final int MEDIUM_THRESHOLD = 50;

    public IncidentService(IncidentRepository repository) {
        this.repository = repository;
    }

    public Incident addNewIncident(Incident incident) {
        incident.setNew(true);

        // 1. คำนวณคะแนน Heuristic Score ใน Backend
        int calculatedScore = calculateHeuristicScore(incident);
        incident.setScore(calculatedScore); // สมมติว่ามี setScore ใน Incident

        // 2. จัดระดับ Rank Level ตามคะแนนที่คำนวณได้
        String rankLevel = determineRankLevel(calculatedScore);
        incident.setRankLevel(rankLevel); // สมมติว่ามี setRankLevel ใน Incident

        // 3. (Optional) ตั้งค่า isRanked ตาม Logic เก่า เพื่อความเข้ากันได้
        if (rankLevel.equals("CRITICAL") || rankLevel.equals("HIGH") || rankLevel.equals("MEDIUM")) {
            incident.setRanked(true);
        } else {
            incident.setRanked(false);
        }


        System.out.println("LOG: Incident Type: " + incident.getType() +
                " scored " + calculatedScore +
                " -> RANK: " + rankLevel);

        // Return the saved incident to the repository
        return repository.save(incident);
    }

    // --- ฟังก์ชันใหม่: คำนวณคะแนน Heuristic Score (จำลอง Logic จาก Flutter) ---
    private int calculateHeuristicScore(Incident i) {
        final var typeWeights = java.util.Map.of(
                "Armed Robbery", 80,
                "Fire", 75,
                "Violent Crime", 70,
                "Medical Emergency", 55,
                "Traffic Accident", 40,
                "Disturbance", 25,
                "Other", 10
        );
        int score = typeWeights.getOrDefault(i.getType(), 10);

        // ปัจจัยเวลา (Nighttime = 22:00 ถึง 05:59)
        if (i.getTime() != null) {
            int hour = i.getTime().getHour();
            if (hour >= 22 || hour <= 5) {
                score += 10;
            }
        }

        // ปัจจัยสถานที่ (เปราะบาง/คนเยอะ)
        String place = i.getPlace().toLowerCase();
        if (place.contains("school") || place.contains("hospital") ||
                place.contains("station") || place.contains("airport") ||
                place.contains("market") || place.contains("stadium") ||
                place.contains("mall") || place.contains("park")) {
            score += 8;
        }

        // ปัจจัยรายละเอียด (Keywords for Severity)
        String notes = i.getNotes().toLowerCase();

        if (notes.contains("weapon") || notes.contains("gun") || notes.contains("knife") ||
                notes.contains("armed") || notes.contains("hostage") || notes.contains("explosion") ||
                notes.contains("gas leak")) {
            score += 25;
        }
        if (notes.contains("fatality") || notes.contains("deceased") ||
                notes.contains("unconscious") || notes.contains("severe injury") ||
                notes.contains("cpr") || notes.contains("major trauma")) {
            score += 20;
        }
        if (notes.contains("large fire") || notes.contains("multiple") ||
                notes.contains("mass") || notes.contains("many people") ||
                notes.contains("crowd")) {
            score += 15;
        }
        if (notes.contains("injur") || notes.contains("bleeding") ||
                notes.contains("child") || notes.contains("elderly") ||
                notes.contains("pregnan")) {
            score += 10;
        }

        // การปรับแต่งขั้นสุดท้าย (เพื่อให้แน่ใจว่าได้ระดับตามเหตุการณ์หลัก)
        if (i.getType().equals("Fire") && score < 75) score = 75;
        if (i.getType().equals("Medical Emergency") && score < 55) score = 55;

        // Armed Robbery + Severe Condition ควรเป็น Critical
        if (i.getType().equals("Armed Robbery") && score < 85) {
            if (notes.contains("weapon") || notes.contains("gun") || notes.contains("knife") ||
                    notes.contains("hostage") || notes.contains("fatality") ||
                    notes.contains("severe injury")) {
                score = 90;
            }
        }

        // จำกัดคะแนน 0-100
        return Math.min(100, Math.max(0, score));
    }

    // --- ฟังก์ชันใหม่: จัดระดับตามเกณฑ์คะแนน ---
    private String determineRankLevel(int score) {
        if (score >= CRITICAL_THRESHOLD) {
            return "CRITICAL";
        } else if (score >= HIGH_THRESHOLD) {
            return "HIGH";
        } else if (score >= MEDIUM_THRESHOLD) {
            return "MEDIUM";
        } else {
            return "LOW";
        }
    }


    // --- Functions เดิม ---
    public int getNewIncidentCount() {
        return repository.findByIsNewTrue().size();
    }

    public List<Incident> getAllIncidents() {
        return repository.findAll();
    }

    public void markAllAsRead() {
        List<Incident> newIncidents = repository.findByIsNewTrue();
        for (Incident i : newIncidents) {
            i.setNew(false);
        }
        repository.saveAll(newIncidents);
    }
}