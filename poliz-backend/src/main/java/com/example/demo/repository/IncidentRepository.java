package com.example.demo.repository;

import com.example.demo.model.Incident;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface IncidentRepository extends JpaRepository<Incident, Long> {

    // ดึงเฉพาะรายการที่ isNew = true
    List<Incident> findByIsNewTrue();
}