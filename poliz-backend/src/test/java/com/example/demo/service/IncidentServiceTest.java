package com.example.demo.service;

import com.example.demo.model.Incident;
import com.example.demo.repository.IncidentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Base-Choice Coverage (Option B): collapse the four note groups into one
 * "Notes Severity" characteristic with 5 partitions:
 *   None (0), Minor(+10), Crowd(+15), Serious(+20), Weapon(+25).
 *
 * Characteristics in this suite:
 *   - Type: {Other, Armed Robbery, Fire, Violent Crime, Medical Emergency, Traffic Accident, Disturbance}
 *   - Time: {Day, Night}
 *   - Place: {Normal, Vulnerable}
 *   - Notes Severity: {None, +10, +15, +20, +25}
 *
 * Total tests = 1 (base) + (7-1) + (2-1) + (2-1) + (5-1) = 13
 */

@ExtendWith(MockitoExtension.class)
public class IncidentServiceTest {
    @Mock IncidentRepository repository;
    @InjectMocks IncidentService service;

    @BeforeEach
    void setup() {
        // Return the same instance on save()
        when(repository.save(any(Incident.class)))
                .thenAnswer(inv -> inv.getArgument(0, Incident.class));
    }

    /** Base-choice builder */
    private Incident baseIncident() {
        Incident i = new Incident();
        i.setType("Other");                                   // base Type
        i.setTime(LocalDateTime.of(2025, 1, 1, 14, 0));       // Daytime
        i.setPlace("office");                                 // Normal place
        i.setNotes("");                                       // Notes Severity: None
        return i;
    }

    // --------------------------
    // BC-0: Base test
    // --------------------------
    @Test
    void BC0_baseChoice_LOW_10pts() {
        Incident out = service.addNewIncident(baseIncident());
        assertTrue(out.isNew());
        assertEquals(10, out.getScore());           // base for "Other"
        assertEquals("LOW", out.getRankLevel());
        assertFalse(out.isRanked());
        verify(repository).save(out);
    }

    // --------------------------
    // Time (2-1) => Night
    // --------------------------
    @Test
    void time_night_adds10_LOW_20pts() {
        Incident i = baseIncident();
        i.setTime(LocalDateTime.of(2025, 1, 1, 23, 0));
        Incident out = service.addNewIncident(i);
        assertEquals(20, out.getScore());           // 10 + 10
        assertEquals("LOW", out.getRankLevel());
    }

    // --------------------------
    // Place (2-1) => Vulnerable
    // --------------------------
    @Test
    void place_vulnerable_adds8_LOW_18pts() {
        Incident i = baseIncident();
        i.setPlace("Central Park");                 // contains "park"
        Incident out = service.addNewIncident(i);
        assertEquals(18, out.getScore());           // 10 + 8
        assertEquals("LOW", out.getRankLevel());
    }

    // --------------------------
    // Notes Severity (5-1) => +10, +15, +20, +25
    // --------------------------
    @Test
    void notes_minor_plus10_LOW_20pts() {
        Incident i = baseIncident();
        i.setNotes("child injured");                // matches injur*/child
        Incident out = service.addNewIncident(i);
        assertEquals(20, out.getScore());           // 10 + 10
        assertEquals("LOW", out.getRankLevel());
    }

    @Test
    void notes_crowd_plus15_LOW_25pts() {
        Incident i = baseIncident();
        i.setNotes("mass crowd incident");          // matches mass/crowd
        Incident out = service.addNewIncident(i);
        assertEquals(25, out.getScore());           // 10 + 15
        assertEquals("LOW", out.getRankLevel());
    }

    @Test
    void notes_serious_plus20_LOW_30pts() {
        Incident i = baseIncident();
        i.setNotes("one person unconscious");       // life-threatening
        Incident out = service.addNewIncident(i);
        assertEquals(30, out.getScore());           // 10 + 20
        assertEquals("LOW", out.getRankLevel());
    }

    @Test
    void notes_weapon_plus25_LOW_35pts() {
        Incident i = baseIncident();
        i.setNotes("suspect with weapon");          // weapon/explosive keywords
        Incident out = service.addNewIncident(i);
        assertEquals(35, out.getScore());           // 10 + 25
        assertEquals("LOW", out.getRankLevel());
    }

    // --------------------------
    // Type (7-1) => switch to the other 6 partitions
    // (Keep other characteristics at base values: Day, Normal, Notes=None)
    // --------------------------
    @Test
    void type_fire_min75_HIGH() {
        Incident i = baseIncident();
        i.setType("Fire");
        Incident out = service.addNewIncident(i);
        assertEquals(75, out.getScore());           // floor rule
        assertEquals("HIGH", out.getRankLevel());
        assertTrue(out.isRanked());
    }

    @Test
    void type_medical_min55_MEDIUM() {
        Incident i = baseIncident();
        i.setType("Medical Emergency");
        Incident out = service.addNewIncident(i);
        assertEquals(55, out.getScore());           // floor rule
        assertEquals("MEDIUM", out.getRankLevel());
        assertTrue(out.isRanked());
    }

    @Test
    void type_armedRobbery_80_HIGH() {
        Incident i = baseIncident();
        i.setType("Armed Robbery");
        Incident out = service.addNewIncident(i);
        assertEquals(80, out.getScore());           // 80 (no severe notes)
        assertEquals("HIGH", out.getRankLevel());   // >=70
        assertTrue(out.isRanked());
    }

    @Test
    void type_violentCrime_70_HIGH() {
        Incident i = baseIncident();
        i.setType("Violent Crime");
        Incident out = service.addNewIncident(i);
        assertEquals(70, out.getScore());
        assertEquals("HIGH", out.getRankLevel());
        assertTrue(out.isRanked());
    }

    @Test
    void type_trafficAccident_40_LOW() {
        Incident i = baseIncident();
        i.setType("Traffic Accident");
        Incident out = service.addNewIncident(i);
        assertEquals(40, out.getScore());
        assertEquals("LOW", out.getRankLevel());
        assertFalse(out.isRanked());
    }

    @Test
    void type_disturbance_25_LOW() {
        Incident i = baseIncident();
        i.setType("Disturbance");
        Incident out = service.addNewIncident(i);
        assertEquals(25, out.getScore());
        assertEquals("LOW", out.getRankLevel());
        assertFalse(out.isRanked());
    }
}
