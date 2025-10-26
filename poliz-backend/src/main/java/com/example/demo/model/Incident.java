package com.example.demo.model; // เปลี่ยน demo เป็น Artifact name ของคุณ

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Data
public class Incident {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String type;
    private String place;
    private LocalDateTime time;
    private String notes;

    private boolean isNew = true;
    private boolean isRanked = false;

    // ===================================================
    // ✨ สิ่งที่ต้องเพิ่มเพื่อรองรับการจัดอันดับ 4 ระดับ
    // ===================================================
    private int score;          // คะแนนตัวเลข (0-100) ที่คำนวณโดย Backend
    private String rankLevel;   // ระดับ (CRITICAL, HIGH, MEDIUM, LOW) ที่คำนวณโดย Backend
    // ===================================================

}