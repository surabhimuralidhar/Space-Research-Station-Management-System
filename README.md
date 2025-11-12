🚀 Space Research Station Database System (SRSDB)

A database-driven management system designed to streamline operations of a space research station — including astronaut management, mission tracking, and automated audit logging — built using Python (Tkinter + ttkbootstrap) and MySQL.

📘 Project Overview

The Space Research Station Database System (SRSDB) is an interactive GUI-based application that enables administrators to manage astronaut details, mission assignments, and maintain automated logs for all database activities.
The project ensures data integrity, accountability, and security through SQL triggers, procedures, and user privilege management.

🧩 Features

👨‍🚀 Astronaut Management

Add, update, and delete astronaut records.

Automatic validation of age and assignment eligibility.

🛰️ Mission Management

Assign astronauts to missions.

Track mission details such as launch date, duration, and assigned personnel.

🧾 Audit Logging

SQL triggers automatically record every INSERT/UPDATE/DELETE in the Audit_Log table.

🛡️ User Privilege System

Role-based privileges for Admin, Supervisor, and Analyst users.

Controlled data access for security and data governance.

🧮 Automated Triggers and Procedures

Audit triggers capture user activity and timestamps.

Stored procedures manage astronaut assignments and mission updates.

💻 Cyborg-themed GUI

Built using ttkbootstrap for a sleek, dark interface.

Intuitive buttons, search, and form-based input fields.

⚙️ Tech Stack
Component	Technology
Frontend (GUI)	Python (Tkinter + ttkbootstrap - Cyborg theme)
Backend (Database)	MySQL
Connector	mysql-connector-python
Language	Python 3.11
IDE/Editor	Visual Studio Code / PyCharm
OS Compatibility	Windows / Linux / macOS



🧰 Functional Highlights
Functionality	Description
Add Astronaut	Inserts new astronaut record into DB
Update Astronaut	Edits astronaut details
Delete Astronaut	Removes astronaut record
Assign Mission	Links astronaut to mission
Auto Audit Log	Trigger logs all DB changes
Search Mission	Filters missions dynamically
🔐 Triggers and Procedures

Trigger:
Automatically logs changes to Astronaut and Mission tables into Audit_Log.

Stored Procedure:
Handles insertion and updates to astronaut details while ensuring audit consistency.

Function:
Validates astronaut age and eligibility dynamically.



🖥️ GUI Preview

💡 Cyborg theme provides a modern, professional dark interface for operators and researchers.

📂 Directory Structure
SpaceResearchStation/
│
├── srs_gui.py                  # Main GUI file
├── srsdb.sql                   # SQL schema and triggers
├── requirements.txt            # Dependencies
├── README.md                   # Documentation


