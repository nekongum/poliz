package com.example.demo.controller;

import com.example.demo.model.Incident;
import com.example.demo.service.IncidentService;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import java.util.List;

@RestController
@RequestMapping("/api/v1/events")
public class IncidentController {

    private final IncidentService service;

    public IncidentController(IncidentService service) {
        this.service = service;
    }

    // POST: Add Incident (ใช้สำหรับปุ่ม Add & Rank)
    @PostMapping
    public ResponseEntity<Incident> addIncident(@RequestBody Incident incident) {
        Incident savedIncident = service.addNewIncident(incident);
        return ResponseEntity.ok(savedIncident);
    }

    // GET: Get Notification Count (ใช้สำหรับ Badge เลขสีแดง)
    @GetMapping("/new/count")
    public ResponseEntity<Integer> getNewIncidentCount() {
        return ResponseEntity.ok(service.getNewIncidentCount());
    }

    // GET: Get All Incidents (ใช้สำหรับหน้า List)
    @GetMapping
    public ResponseEntity<List<Incident>> getAllIncidents() {
        return ResponseEntity.ok(service.getAllIncidents());
    }

    // POST: Mark All As Read (ใช้เมื่อเข้าหน้า Notification)
    @PostMapping("/mark-as-read")
    public ResponseEntity<Void> markAllAsRead() {
        service.markAllAsRead();
        return ResponseEntity.noContent().build();
    }
}