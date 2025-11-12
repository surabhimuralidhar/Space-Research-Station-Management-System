-- srsdb_setup_full.sql
-- Full SRS DB: tables (unchanged), users, privileges, sample data, procs, funcs, triggers, views, queries
DROP DATABASE IF EXISTS srsdb;
CREATE DATABASE srsdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE srsdb;


DROP USER IF EXISTS 'admin_srs'@'localhost';
DROP USER IF EXISTS 'operator_srs'@'localhost';
DROP USER IF EXISTS 'viewer_srs'@'localhost';

CREATE USER 'admin_srs'@'localhost' IDENTIFIED BY 'Admin@123';
CREATE USER 'operator_srs'@'localhost' IDENTIFIED BY 'Operator@123';
CREATE USER 'viewer_srs'@'localhost' IDENTIFIED BY 'Viewer@123';

-- ADMIN USER → Full privileges
GRANT ALL PRIVILEGES ON srsdb.* TO 'admin_srs'@'localhost' WITH GRANT OPTION;

-- OPERATOR USER → Read, Insert, Update
GRANT SELECT, INSERT, UPDATE ON srsdb.* TO 'operator_srs'@'localhost';

-- VIEWER USER → Read-only
GRANT SELECT ON srsdb.* TO 'viewer_srs'@'localhost';

-- Apply privileges
FLUSH PRIVILEGES;

-- Verify
SHOW GRANTS FOR 'admin_srs'@'localhost';
SHOW GRANTS FOR 'operator_srs'@'localhost';
SHOW GRANTS FOR 'viewer_srs'@'localhost';
-- =========================
-- 1) Strong entities (exactly as provided)
-- =========================
CREATE TABLE Astronauts (
  AstronautID    INT AUTO_INCREMENT PRIMARY KEY,
  FirstName      VARCHAR(100) NOT NULL,
  LastName       VARCHAR(100) NOT NULL,
  DOB            DATE,
  Nationality    VARCHAR(80),
  JobTitle       VARCHAR(80),
  MedicalStatus  VARCHAR(60)
) ENGINE=InnoDB;

CREATE TABLE AstronautSkills (
  AstronautID INT NOT NULL,
  Skill       VARCHAR(100) NOT NULL,
  PRIMARY KEY (AstronautID, Skill),
  CONSTRAINT fk_as_sk_as FOREIGN KEY (AstronautID) REFERENCES Astronauts(AstronautID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Missions (
  MissionID      INT AUTO_INCREMENT PRIMARY KEY,
  MissionName    VARCHAR(200) NOT NULL UNIQUE,
  LaunchDate     DATE,
  ReturnDate     DATE,
  MissionType    VARCHAR(80),
  CurrentStatus  VARCHAR(20) DEFAULT 'Planned'
) ENGINE=InnoDB;

CREATE TABLE StationModules (
  ModuleID      INT AUTO_INCREMENT PRIMARY KEY,
  ModuleName    VARCHAR(150) NOT NULL UNIQUE,
  ModuleType    VARCHAR(80),
  Capacity      INT UNSIGNED,
  CurrentStatus VARCHAR(40),
  Location      VARCHAR(120)
) ENGINE=InnoDB;

CREATE TABLE Resources (
  ResourceID   INT AUTO_INCREMENT PRIMARY KEY,
  ResourceName VARCHAR(150) NOT NULL,
  Unit         VARCHAR(50),
  Description  TEXT
) ENGINE=InnoDB;

CREATE TABLE Supplies (
  SupplyID        INT AUTO_INCREMENT PRIMARY KEY,
  ResourceID      INT NOT NULL,
  Quantity        DECIMAL(18,3) NOT NULL DEFAULT 0,
  Unit            VARCHAR(50),
  ExpiryDate      DATE,
  SupplierName    VARCHAR(150),
  StorageModuleID INT,
  CONSTRAINT fk_supplies_resource FOREIGN KEY (ResourceID) REFERENCES Resources(ResourceID) ON DELETE CASCADE,
  CONSTRAINT fk_supplies_module FOREIGN KEY (StorageModuleID) REFERENCES StationModules(ModuleID) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE LifeSupportSystems (
  SystemID    INT AUTO_INCREMENT PRIMARY KEY,
  ModuleID    INT NOT NULL UNIQUE,
  SystemType  VARCHAR(80),
  OxygenLevel DECIMAL(10,3),
  Pressure    DECIMAL(10,3),
  Temperature DECIMAL(6,2),
  CO2Level    DECIMAL(10,3),
  CurrentStatus VARCHAR(40),
  CONSTRAINT fk_lss_module FOREIGN KEY (ModuleID) REFERENCES StationModules(ModuleID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Spacecrafts (
  SpacecraftID INT AUTO_INCREMENT PRIMARY KEY,
  Name         VARCHAR(150) NOT NULL UNIQUE,
  SystemType   VARCHAR(80),
  CrewCapacity INT UNSIGNED,
  CargoCapacity DECIMAL(12,2),
  LaunchDate   DATE,
  CurrentStatus VARCHAR(40)
) ENGINE=InnoDB;

-- =========================
-- 2) Weak / dependent entities (exactly as provided)
-- =========================
CREATE TABLE Experiments (
  ExperimentID INT AUTO_INCREMENT PRIMARY KEY,
  MissionID    INT NOT NULL,
  Title        VARCHAR(250) NOT NULL,
  Objective    TEXT,
  Category     VARCHAR(80),
  CurrentStatus VARCHAR(40),
  ModuleID     INT,
  LeadAstronautID INT,
  CONSTRAINT fk_experiments_mission FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE,
  CONSTRAINT fk_experiments_module FOREIGN KEY (ModuleID) REFERENCES StationModules(ModuleID) ON DELETE SET NULL,
  CONSTRAINT fk_experiments_lead FOREIGN KEY (LeadAstronautID) REFERENCES Astronauts(AstronautID) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE Schedules (
  ScheduleID   INT AUTO_INCREMENT PRIMARY KEY,
  MissionID    INT NOT NULL,
  TaskDescription TEXT,
  TaskType     VARCHAR(80),
  StartTime    DATETIME,
  EndTime      DATETIME,
  AstronautID  INT,
  CurrentStatus VARCHAR(40),
  CONSTRAINT fk_schedules_mission FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE,
  CONSTRAINT fk_schedules_astronaut FOREIGN KEY (AstronautID) REFERENCES Astronauts(AstronautID) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE MedicalRecords (
  RecordID     INT AUTO_INCREMENT PRIMARY KEY,
  AstronautID  INT NOT NULL,
  CheckupDate  DATE,
  HealthCondition VARCHAR(200),
  Treatment    TEXT,
  DoctorID     INT,
  CONSTRAINT fk_med_astronaut FOREIGN KEY (AstronautID) REFERENCES Astronauts(AstronautID) ON DELETE CASCADE,
  CONSTRAINT fk_med_doctor FOREIGN KEY (DoctorID) REFERENCES Astronauts(AstronautID) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE ResourceAllocations (
  AllocationID      INT AUTO_INCREMENT PRIMARY KEY,
  MissionID         INT NOT NULL,
  SupplyID          INT NOT NULL,
  QuantityAllocated DECIMAL(18,3) NOT NULL,
  AllocationDate    DATETIME DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_alloc_mission FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE,
  CONSTRAINT fk_alloc_supply FOREIGN KEY (SupplyID) REFERENCES Supplies(SupplyID) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Communications (
  CommID       INT AUTO_INCREMENT PRIMARY KEY,
  MissionID     INT NOT NULL,
  AstronautID   INT,
  MessageType   VARCHAR(80),
  TimeStamp     DATETIME DEFAULT CURRENT_TIMESTAMP,
  MessageContent TEXT,
  Recipient     VARCHAR(200),
  CONSTRAINT fk_comm_mission FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE,
  CONSTRAINT fk_comm_astronaut FOREIGN KEY (AstronautID) REFERENCES Astronauts(AstronautID) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE Anomalies (
  AnomalyID    INT AUTO_INCREMENT PRIMARY KEY,
  ModuleID     INT NOT NULL,
  DateDetected DATE DEFAULT (CURRENT_DATE),
  Severity     ENUM('Low','Medium','High','Critical') NOT NULL,
  Description  TEXT,
  ResolvedByAstronautID INT,
  ResolutionDate DATE,
  CONSTRAINT fk_anom_module FOREIGN KEY (ModuleID) REFERENCES StationModules(ModuleID) ON DELETE CASCADE,
  CONSTRAINT fk_anom_resolver FOREIGN KEY (ResolvedByAstronautID) REFERENCES Astronauts(AstronautID) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =========================
-- 3) mapping tables (composite PKs) - preserved
-- =========================
CREATE TABLE Astronaut_Missions (
  AstronautID INT NOT NULL,
  MissionID   INT NOT NULL,
  Role        VARCHAR(100),
  HoursWorked DECIMAL(10,2) DEFAULT 0,
  PRIMARY KEY (AstronautID, MissionID),
  CONSTRAINT fk_am_as FOREIGN KEY (AstronautID) REFERENCES Astronauts(AstronautID) ON DELETE CASCADE,
  CONSTRAINT fk_am_mi FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Mission_Spacecraft (
  MissionID INT NOT NULL,
  SpacecraftID INT NOT NULL,
  AssignmentDate DATE DEFAULT (CURRENT_DATE),
  PRIMARY KEY (MissionID, SpacecraftID),
  CONSTRAINT fk_ms_mi FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE,
  CONSTRAINT fk_ms_sp FOREIGN KEY (SpacecraftID) REFERENCES Spacecrafts(SpacecraftID) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Mission_Modules (
  MissionID INT NOT NULL,
  ModuleID  INT NOT NULL,
  AssignmentDate DATE DEFAULT (CURRENT_DATE),
  PRIMARY KEY (MissionID, ModuleID),
  CONSTRAINT fk_mm_mi FOREIGN KEY (MissionID) REFERENCES Missions(MissionID) ON DELETE CASCADE,
  CONSTRAINT fk_mm_mod FOREIGN KEY (ModuleID) REFERENCES StationModules(ModuleID) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Experiment_Astronauts (
  ExperimentID INT NOT NULL,
  AstronautID  INT NOT NULL,
  Role         VARCHAR(80),
  PRIMARY KEY (ExperimentID, AstronautID),
  CONSTRAINT fk_ea_exp FOREIGN KEY (ExperimentID) REFERENCES Experiments(ExperimentID) ON DELETE CASCADE,
  CONSTRAINT fk_ea_as FOREIGN KEY (AstronautID) REFERENCES Astronauts(AstronautID) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =========================
-- audit
-- =========================
CREATE TABLE AuditLog (
  AuditID    INT AUTO_INCREMENT PRIMARY KEY,
  TableName  VARCHAR(200) NOT NULL,
  Operation  VARCHAR(10) NOT NULL,
  KeyData    VARCHAR(500),
  OldRow     JSON,
  NewRow     JSON,
  ChangedAt  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =========================
-- Indexes
-- =========================
CREATE INDEX idx_supplies_resource ON Supplies(ResourceID);
CREATE INDEX idx_allocations_mission ON ResourceAllocations(MissionID);
CREATE INDEX idx_allocations_supply ON ResourceAllocations(SupplyID);
CREATE INDEX idx_experiments_mission ON Experiments(MissionID);
CREATE INDEX idx_anomalies_module ON Anomalies(ModuleID);
CREATE INDEX idx_comm_mission ON Communications(MissionID);

-- =========================
-- 4) FUNCTIONS (2)
-- =========================
DROP FUNCTION IF EXISTS fn_mission_duration;
DELIMITER $$
CREATE FUNCTION fn_mission_duration(p_missionid INT)
RETURNS INT DETERMINISTIC
BEGIN
  DECLARE v_launch DATE;
  DECLARE v_return DATE;
  DECLARE v_days INT;
  SELECT LaunchDate, ReturnDate INTO v_launch, v_return FROM Missions WHERE MissionID = p_missionid;
  IF v_launch IS NULL OR v_return IS NULL THEN
    RETURN NULL;
  END IF;
  SET v_days = DATEDIFF(v_return, v_launch);
  RETURN v_days;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_remaining_supply;
DELIMITER $$
CREATE FUNCTION fn_remaining_supply(p_supplyid INT)
RETURNS DECIMAL(18,3) DETERMINISTIC
BEGIN
  DECLARE q DECIMAL(18,3);
  SELECT Quantity INTO q FROM Supplies WHERE SupplyID = p_supplyid;
  RETURN IFNULL(q, 0);
END$$
DELIMITER ;

-- =========================
-- 5) PROCEDURES (2)
-- =========================
DROP PROCEDURE IF EXISTS sp_allocate_supply;
DELIMITER $$
CREATE PROCEDURE sp_allocate_supply(
  IN p_missionid INT,
  IN p_supplyid INT,
  IN p_qty DECIMAL(18,3)
)
BEGIN
  DECLARE cur_qty DECIMAL(18,3);
  DECLARE v_err_msg VARCHAR(255);

  IF p_qty <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be positive';
  END IF;

  IF (SELECT COUNT(*) FROM Missions WHERE MissionID = p_missionid) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mission not found';
  END IF;

  START TRANSACTION;
    SELECT Quantity INTO cur_qty FROM Supplies WHERE SupplyID = p_supplyid FOR UPDATE;
    IF cur_qty IS NULL THEN
      ROLLBACK;
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supply not found';
    END IF;
    IF cur_qty < p_qty THEN
      SET v_err_msg = CONCAT('Insufficient stock. Available: ', cur_qty);
      ROLLBACK;
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_err_msg;
    END IF;

    UPDATE Supplies SET Quantity = Quantity - p_qty WHERE SupplyID = p_supplyid;
    INSERT INTO ResourceAllocations (MissionID, SupplyID, QuantityAllocated, AllocationDate)
      VALUES (p_missionid, p_supplyid, p_qty, NOW());
  COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_create_experiment;
DELIMITER $$
CREATE PROCEDURE sp_create_experiment(
  IN p_missionid INT,
  IN p_title VARCHAR(250),
  IN p_objective TEXT,
  IN p_category VARCHAR(80),
  IN p_moduleid INT,
  IN p_leadastronautid INT,
  OUT p_expid INT
)
BEGIN
  IF (SELECT COUNT(*) FROM Missions WHERE MissionID = p_missionid) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mission not found';
  END IF;

  INSERT INTO Experiments (MissionID, Title, Objective, Category, CurrentStatus, ModuleID, LeadAstronautID)
    VALUES (p_missionid, p_title, p_objective, p_category, 'Planned', p_moduleid, p_leadastronautid);
  SET p_expid = LAST_INSERT_ID();
END$$
DELIMITER ;

-- =========================
-- 6) TRIGGERS (2)
-- =========================
DROP TRIGGER IF EXISTS trg_audit_supplies_after;
DELIMITER $$
CREATE TRIGGER trg_audit_supplies_after
AFTER INSERT ON Supplies
FOR EACH ROW
BEGIN
  INSERT INTO AuditLog (TableName, Operation, KeyData, NewRow)
    VALUES ('Supplies', 'INSERT', CONCAT('SupplyID=', NEW.SupplyID), JSON_OBJECT('SupplyID', NEW.SupplyID, 'ResourceID', NEW.ResourceID, 'Quantity', NEW.Quantity));
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_before_alloc_insert;
DELIMITER $$
CREATE TRIGGER trg_before_alloc_insert
BEFORE INSERT ON ResourceAllocations
FOR EACH ROW
BEGIN
  DECLARE cur_qty DECIMAL(18,3);
  SELECT Quantity INTO cur_qty FROM Supplies WHERE SupplyID = NEW.SupplyID FOR UPDATE;
  IF cur_qty IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supply not found (trigger)';
  END IF;
  IF cur_qty < NEW.QuantityAllocated THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough supply (trigger)';
  END IF;
  -- trigger also deducts stock to keep ResourceAllocations safe if insertion proceeds
  UPDATE Supplies SET Quantity = Quantity - NEW.QuantityAllocated WHERE SupplyID = NEW.SupplyID;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_check_astronaut_dob_insert;
DELIMITER $$

CREATE TRIGGER trg_check_astronaut_dob_insert
BEFORE INSERT ON Astronauts
FOR EACH ROW
BEGIN
    IF TIMESTAMPDIFF(YEAR, NEW.DOB, CURDATE()) < 22 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Astronaut must be at least 22 years old.';
    END IF;
END$$

DELIMITER ;

DROP TRIGGER IF EXISTS trg_check_astronaut_dob_update;
DELIMITER $$

CREATE TRIGGER trg_check_astronaut_dob_update
BEFORE UPDATE ON Astronauts
FOR EACH ROW
BEGIN
    IF TIMESTAMPDIFF(YEAR, NEW.DOB, CURDATE()) < 22 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Astronaut must be at least 22 years old.';
    END IF;
END$$

DELIMITER ;

-- =========================
-- 7) VIEWS
-- =========================
DROP VIEW IF EXISTS vw_LowStock;
CREATE VIEW vw_LowStock AS
SELECT s.SupplyID, r.ResourceName, s.Quantity, s.Unit, s.StorageModuleID
FROM Supplies s JOIN Resources r ON s.ResourceID = r.ResourceID
WHERE s.Quantity < 50;

DROP VIEW IF EXISTS vw_ActiveMissions;
CREATE VIEW vw_ActiveMissions AS
SELECT MissionID, MissionName, LaunchDate, CurrentStatus FROM Missions WHERE CurrentStatus IN ('Active','Planned');

DROP VIEW IF EXISTS vw_ExperimentSummary;
CREATE VIEW vw_ExperimentSummary AS
SELECT e.ExperimentID, e.Title, m.MissionName, e.CurrentStatus, sm.ModuleName
FROM Experiments e
LEFT JOIN Missions m ON e.MissionID = m.MissionID
LEFT JOIN StationModules sm ON e.ModuleID = sm.ModuleID;

DROP VIEW IF EXISTS vw_ModuleAnomalies;
CREATE VIEW vw_ModuleAnomalies AS
SELECT sm.ModuleID, sm.ModuleName, COUNT(a.AnomalyID) AS AnomalyCount
FROM StationModules sm
LEFT JOIN Anomalies a ON a.ModuleID = sm.ModuleID
GROUP BY sm.ModuleID, sm.ModuleName;

DROP VIEW IF EXISTS vw_AstronautHealth;
CREATE VIEW vw_AstronautHealth AS
SELECT a.AstronautID, CONCAT(a.FirstName,' ',a.LastName) AS Name, a.MedicalStatus,
       MAX(mr.CheckupDate) AS LastCheckup
FROM Astronauts a
LEFT JOIN MedicalRecords mr ON a.AstronautID = mr.AstronautID
GROUP BY a.AstronautID, a.FirstName, a.LastName, a.MedicalStatus;

-- =========================
-- 8) SAMPLE DATA (5 entries per core table) - insert parents first
-- Note: choose values so foreign keys work when mapping rows inserted after parents.
-- =========================

-- StationModules (parent for Supplies, LifeSupport, Experiments module etc.)
INSERT INTO StationModules (ModuleName, ModuleType, Capacity, CurrentStatus, Location) VALUES
('Habitat-1','Habitat',6,'Operational','Node-A'),
('Lab-Alpha','Research',4,'Operational','Node-B'),
('Engineering-1','Engineering',3,'Operational','Node-C'),
('Storage-1','Storage',10,'Operational','Node-D'),
('Test-Module','Research',2,'Operational','Node-E');

-- Astronauts
INSERT INTO Astronauts (FirstName, LastName, DOB, Nationality, JobTitle, MedicalStatus) VALUES
('Anil','Sharma','1985-07-20','India','Flight Engineer','Fit'),
('Sara','Lopez','1990-11-05','Spain','Lead Scientist','Fit'),
('James','Owen','1982-03-12','USA','Commander','Fit'),
('Mina','Khan','1992-09-25','Pakistan','Medical Officer','Fit'),
('Liu','Wei','1987-06-15','China','Technician','Fit');

-- Resources
INSERT INTO Resources (ResourceName, Unit, Description) VALUES
('Oxygen','Liters','Breathable oxygen cylinders'),
('Water','Liters','Potable water tanks'),
('Food','Kg','Packaged meals'),
('SpareParts','Units','Mechanical spare components'),
('ScienceKits','Units','Experimental kits');

-- Supplies (depends on Resources & StationModules)
INSERT INTO Supplies (ResourceID, Quantity, Unit, ExpiryDate, SupplierName, StorageModuleID) VALUES
(1, 10000.000, 'Liters', '2030-01-01', 'SpaceSupplyCo', 1),
(2, 5000.000, 'Liters', '2029-05-01', 'HydroSupplies', 4),
(3, 2000.000, 'Kg', '2027-12-31', 'FoodForSpace', 4),
(4, 150.000, 'Units', NULL, 'OrbitalParts', 3),
(5, 50.000, 'Units', NULL, 'LabKitsInc', 2);

-- Spacecrafts
INSERT INTO Spacecrafts (Name, SystemType, CrewCapacity, CargoCapacity, LaunchDate, CurrentStatus) VALUES
('Aurora','Crew',4,1200.00,'2025-05-01','Docked'),
('Odyssey','Cargo',0,3000.00,'2024-11-12','InTransit'),
('Orion-X3','Crew',8,12000.00,'2027-01-01','Ready'),
('Pegasus','Cargo',0,2500.00,'2026-03-10','Docked'),
('Hermes','Crew',6,5000.00,'2026-07-22','Ready');

-- Missions
INSERT INTO Missions (MissionName, LaunchDate, ReturnDate, MissionType, CurrentStatus) VALUES
('SRS-Alpha','2026-01-10', NULL,'Research','Planned'),
('SRS-Resupply-1','2025-11-20', NULL,'Supply','Active'),
('SRS-Maint-1','2025-12-05','2025-12-20','Maintenance','Completed'),
('Lunar-Test','2027-02-10', NULL,'Test','Planned'),
('Orbital-Physics','2026-06-01', '2026-06-20','Research','Completed');

-- Experiments (needs Missions and optional Module/Lead)
INSERT INTO Experiments (MissionID, Title, Objective, Category, CurrentStatus, ModuleID, LeadAstronautID) VALUES
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha' LIMIT 1),'Microgravity Plant Growth','Study plant growth in microgravity','Biology','Planned',2,2),
((SELECT MissionID FROM Missions WHERE MissionName='Orbital-Physics' LIMIT 1),'Radiation Shielding Test','Test composite material shielding','Materials','Planned',3,1),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1' LIMIT 1),'Cargo Handling Efficiency','Improve cargo handling','Engineering','Completed',3,1),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Maint-1' LIMIT 1),'Thermal Test','System thermal validation','Engineering','Completed',3,5),
((SELECT MissionID FROM Missions WHERE MissionName='Lunar-Test' LIMIT 1),'Lunar Regolith Study','Analyze regolith simulant','Geology','Planned',2,4);

-- Schedules
INSERT INTO Schedules (MissionID, TaskDescription, TaskType, StartTime, EndTime, AstronautID, CurrentStatus) VALUES
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 'Plant setup in Lab-Alpha','Research','2026-02-02 09:00:00','2026-02-02 12:00:00', (SELECT AstronautID FROM Astronauts WHERE FirstName='Sara' LIMIT 1),'Scheduled'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1'), 'Unload supplies','Logistics','2025-11-21 08:00:00','2025-11-21 12:00:00', (SELECT AstronautID FROM Astronauts WHERE FirstName='Anil' LIMIT 1),'Completed'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Maint-1'), 'Radiation sensor calibration','Maintenance','2025-12-03 10:00:00','2025-12-03 12:00:00', (SELECT AstronautID FROM Astronauts WHERE FirstName='Liu' LIMIT 1),'Completed'),
((SELECT MissionID FROM Missions WHERE MissionName='Orbital-Physics'), 'Instrument setup','Research','2026-06-02 09:00:00','2026-06-02 12:00:00', (SELECT AstronautID FROM Astronauts WHERE FirstName='James' LIMIT 1),'Planned'),
((SELECT MissionID FROM Missions WHERE MissionName='Lunar-Test'), 'Regolith sample prep','Research','2027-02-15 09:00:00','2027-02-15 12:00:00', (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina' LIMIT 1),'Planned');

-- MedicalRecords
INSERT INTO MedicalRecords (AstronautID, CheckupDate, HealthCondition, Treatment, DoctorID) VALUES
((SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'), '2025-12-20','Healthy','None', (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina')),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Sara'), '2025-12-21','Minor cold','Rest & meds', (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina')),
((SELECT AstronautID FROM Astronauts WHERE FirstName='James'), '2025-11-01','Normal','Routine', (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina')),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'), '2025-11-05','Normal','Routine', (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina')),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Liu'), '2025-10-10','Muscle fatigue','Physiotherapy', (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'));

-- Communications
INSERT INTO Communications (MissionID, AstronautID, MessageType, MessageContent, Recipient) VALUES
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Sara'),'Data','Telemetry packet #001','GroundControl'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'),'Voice','Status OK','GroundControl'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1'), NULL,'Notice','Docking scheduled','GroundControl'),
((SELECT MissionID FROM Missions WHERE MissionName='Orbital-Physics'), (SELECT AstronautID FROM Astronauts WHERE FirstName='James'),'Data','Instrument reporting','GroundControl'),
((SELECT MissionID FROM Missions WHERE MissionName='Lunar-Test'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'),'Data','Sample collected','GroundControl');

-- Anomalies
INSERT INTO Anomalies (ModuleID, DateDetected, Severity, Description) VALUES
(2, CURDATE(), 'Medium', 'Temperature spike in lab'),
(3, CURDATE(), 'Low', 'Minor vibration detected'),
(1, CURDATE(), 'High', 'Oxygen fluctuation'),
(4, CURDATE(), 'Low', 'Storage compartment sensor fault'),
(2, CURDATE(), 'Medium', 'Humidity increase');

-- LifeSupportSystems (module references)
INSERT INTO LifeSupportSystems (ModuleID, SystemType, OxygenLevel, Pressure, Temperature, CO2Level, CurrentStatus) VALUES
(1,'O2_Recycler',20900,101.3,22.5,400,'OK'),
(2,'Env_Control',20850,101.1,22.0,410,'OK'),
(3,'Power_Env',20750,101.0,21.8,420,'OK'),
(4,'Storage_Control',20600,100.9,21.5,425,'OK'),
(5,'Test_O2',20500,100.8,21.2,430,'OK');

-- AstronautSkills
INSERT INTO AstronautSkills (AstronautID, Skill) VALUES
((SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'),'Robotics'),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'),'EVA'),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Sara'),'Astrobiology'),
((SELECT AstronautID FROM Astronauts WHERE FirstName='James'),'Navigation'),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'),'Medicine');

-- Astronaut_Missions mapping
INSERT INTO Astronaut_Missions (AstronautID, MissionID, Role, HoursWorked) VALUES
((SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'), (SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 'Flight Engineer', 0),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Sara'), (SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 'Lead Scientist', 0),
((SELECT AstronautID FROM Astronauts WHERE FirstName='James'), (SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 'Commander', 0),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'), (SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 'Medical Officer', 0),
((SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'), (SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1'), 'Engineer', 5);

-- Mission_Spacecraft mapping
INSERT INTO Mission_Spacecraft (MissionID, SpacecraftID, AssignmentDate) VALUES
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), (SELECT SpacecraftID FROM Spacecrafts WHERE Name='Aurora'), '2026-01-08'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1'), (SELECT SpacecraftID FROM Spacecrafts WHERE Name='Odyssey'), '2025-11-18'),
((SELECT MissionID FROM Missions WHERE MissionName='Orbital-Physics'), (SELECT SpacecraftID FROM Spacecrafts WHERE Name='Hermes'), '2026-05-20'),
((SELECT MissionID FROM Missions WHERE MissionName='Lunar-Test'), (SELECT SpacecraftID FROM Spacecrafts WHERE Name='Orion-X3'), '2027-01-01'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Maint-1'), (SELECT SpacecraftID FROM Spacecrafts WHERE Name='Pegasus'), '2025-12-01');

-- Mission_Modules mapping
INSERT INTO Mission_Modules (MissionID, ModuleID, AssignmentDate) VALUES
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 2, '2026-01-09'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 1, '2026-01-09'),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1'), 4, '2025-11-18'),
((SELECT MissionID FROM Missions WHERE MissionName='Orbital-Physics'), 2, '2026-05-21'),
((SELECT MissionID FROM Missions WHERE MissionName='Lunar-Test'), 5, '2027-01-05');

-- Experiment_Astronauts mapping (now that experiments & astronauts exist)
INSERT INTO Experiment_Astronauts (ExperimentID, AstronautID, Role) VALUES
((SELECT ExperimentID FROM Experiments WHERE Title='Microgravity Plant Growth'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Sara'), 'Principal Investigator'),
((SELECT ExperimentID FROM Experiments WHERE Title='Microgravity Plant Growth'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'), 'Technician'),
((SELECT ExperimentID FROM Experiments WHERE Title='Radiation Shielding Test'), (SELECT AstronautID FROM Astronauts WHERE FirstName='James'), 'Lead Technician'),
((SELECT ExperimentID FROM Experiments WHERE Title='Radiation Shielding Test'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'), 'Medical Support'),
((SELECT ExperimentID FROM Experiments WHERE Title='Lunar Regolith Study'), (SELECT AstronautID FROM Astronauts WHERE FirstName='Mina'), 'Lead');

-- ResourceAllocations (use sp_allocate_supply or direct inserts - make sure supplies exist)
INSERT INTO ResourceAllocations (MissionID, SupplyID, QuantityAllocated) VALUES
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), (SELECT SupplyID FROM Supplies WHERE SupplierName='SpaceSupplyCo' LIMIT 1), 200.000),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), (SELECT SupplyID FROM Supplies WHERE SupplierName='HydroSupplies' LIMIT 1), 100.000),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Resupply-1'), (SELECT SupplyID FROM Supplies WHERE SupplierName='FoodForSpace' LIMIT 1), 50.000),
((SELECT MissionID FROM Missions WHERE MissionName='SRS-Maint-1'), (SELECT SupplyID FROM Supplies WHERE SupplierName='OrbitalParts' LIMIT 1), 5.000),
((SELECT MissionID FROM Missions WHERE MissionName='Orbital-Physics'), (SELECT SupplyID FROM Supplies WHERE SupplierName='LabKitsInc' LIMIT 1), 10.000);

-- =========================
-- 9) USERS & PRIVILEGES (3 users)
-- =========================

-- Create users (if MySQL server requires plugin/host update remove IF NOT EXISTS)
DROP USER IF EXISTS 'admin_srs'@'localhost';
DROP USER IF EXISTS 'operator_srs'@'localhost';
DROP USER IF EXISTS 'viewer_srs'@'localhost';

CREATE USER 'admin_srs'@'localhost' IDENTIFIED BY 'Admin@123';
CREATE USER 'operator_srs'@'localhost' IDENTIFIED BY 'Op@123';
CREATE USER 'viewer_srs'@'localhost' IDENTIFIED BY 'View@123';

GRANT ALL PRIVILEGES ON srsdb.* TO 'admin_srs'@'localhost' WITH GRANT OPTION;

-- operator: DML on core operational tables + execute on procs/functions
GRANT SELECT, INSERT, UPDATE, DELETE ON srsdb.Astronauts TO 'operator_srs'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON srsdb.Missions TO 'operator_srs'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON srsdb.Experiments TO 'operator_srs'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON srsdb.Supplies TO 'operator_srs'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON srsdb.Schedules TO 'operator_srs'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON srsdb.MedicalRecords TO 'operator_srs'@'localhost';
GRANT EXECUTE ON PROCEDURE srsdb.sp_allocate_supply TO 'operator_srs'@'localhost';
GRANT EXECUTE ON PROCEDURE srsdb.sp_create_experiment TO 'operator_srs'@'localhost';
GRANT EXECUTE ON FUNCTION srsdb.fn_mission_duration TO 'operator_srs'@'localhost';
GRANT EXECUTE ON FUNCTION srsdb.fn_remaining_supply TO 'operator_srs'@'localhost';

-- viewer: can read views and some tables
GRANT SELECT ON srsdb.vw_LowStock TO 'viewer_srs'@'localhost';
GRANT SELECT ON srsdb.vw_ActiveMissions TO 'viewer_srs'@'localhost';
GRANT SELECT ON srsdb.vw_ExperimentSummary TO 'viewer_srs'@'localhost';
GRANT SELECT ON srsdb.vw_ModuleAnomalies TO 'viewer_srs'@'localhost';
GRANT SELECT ON srsdb.vw_AstronautHealth TO 'viewer_srs'@'localhost';
GRANT SELECT ON srsdb.Astronauts TO 'viewer_srs'@'localhost';
GRANT SELECT ON srsdb.Missions TO 'viewer_srs'@'localhost';

FLUSH PRIVILEGES;

-- =========================
-- 10) Verify calls / sample stored calls (non-destructive)
-- =========================
-- You can run these manually after import to verify:
-- SELECT fn_mission_duration((SELECT MissionID FROM Missions WHERE MissionName='SRS-Maint-1'));
-- SELECT fn_remaining_supply((SELECT SupplyID FROM Supplies WHERE SupplierName='SpaceSupplyCo' LIMIT 1));
-- CALL sp_allocate_supply((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), (SELECT SupplyID FROM Supplies WHERE SupplierName='SpaceSupplyCo' LIMIT 1), 1.000);
-- CALL sp_create_experiment((SELECT MissionID FROM Missions WHERE MissionName='SRS-Alpha'), 'Test Exp', 'Objective', 'Test', 2, (SELECT AstronautID FROM Astronauts WHERE FirstName='Anil'), @outid); SELECT @outid;

-- =========================
-- 11) Helpful example queries (separate from procedures)
-- =========================
-- JOIN query (example):
SELECT A.AstronautID, CONCAT(A.FirstName,' ',A.LastName) AS Name, M.MissionName, AM.Role
FROM Astronauts A
JOIN Astronaut_Missions AM ON A.AstronautID = AM.AstronautID
JOIN Missions M ON M.MissionID = AM.MissionID;

-- Aggregate query (example):
SELECT SM.ModuleName, AVG(LSS.OxygenLevel) AS AvgOxygen
FROM LifeSupportSystems LSS
JOIN StationModules SM ON SM.ModuleID = LSS.ModuleID
GROUP BY SM.ModuleName;

-- Nested query (example, not a stored proc):
SELECT m.MissionID, m.MissionName, COUNT(e.ExperimentID) AS expCount
FROM Missions m
LEFT JOIN Experiments e ON m.MissionID = e.MissionID
GROUP BY m.MissionID, m.MissionName
HAVING COUNT(e.ExperimentID) > (
   SELECT AVG(t.cnt) FROM (
   SELECT COUNT(*) AS cnt FROM Experiments GROUP BY MissionID
   ) AS t
 );

-- =========================
-- Done.
-- =========================

