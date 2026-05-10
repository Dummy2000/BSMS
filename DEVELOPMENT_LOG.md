# BSMS Development Log

## Step 1 – App Architecture 
Stiina

Defined the layered architecture (BLE → Data → Processing → UI). 

Mapped the full data flow from the ECG device to real‑time visualization. 

Identified core screens and their responsibilities. 

 

## Step 2 – Project Structure 
Stiina

Created a clean Flutter folder structure aligned with the architecture. 

Separated BLE, data handling, domain logic, signal processing, and UI. 

Ensured scalability and testability before implementation. 

 

## Step 3 – Core Models & Packet Handling 
Stiina

Defined the structure of core domain models (samples, HR, events, sessions). 

Outlined how BLE packets will be parsed into internal models. 

Added the initial parser and packet model scaffolding. 

 

## Step 4 – Task Breakdown 
Stiina

Split the project into Dev A/B/C/D workstreams. 

Defined responsibilities and parallel development paths. 

Enabled multiple developers to work independently. 

 

## Step 5 – BLE Layer Foundation 
Stiina

Rebuilt the BLE folder under lib/data/ble/ and removed legacy code. 

Implemented scanning and connection management using flutter_reactive_ble. 

Updated dependencies and verified the project builds successfully. 

 

## Step 6 – Parser Scaffolding & Team Unblocking 
Stiina

Added EcgPacket and EcgPacketParser skeletons (no logic yet). 

Fixed imports and ensured the BLE layer compiles cleanly. 

Confirmed Dev B, C, and D can proceed without the packet format. 

Documented the current blocker: final 47‑byte packet structure pending.

## Step 7 – EKG-Holter BLE Specification Implementation
Stiina

Implemented the complete 47-byte packet parser (format: <IBBB20H).

Integrated BLE scanning, connection, and notification subscription via flutter_reactive_ble.

Created ring buffer for fixed-size ECG sample storage with overflow handling.

Built data pipeline connecting BLE → parser → buffer → UI stream emission at 10Hz.

Created integration test validating complete pipeline without BLE hardware (MockEcgDataPipeline).

Confirmed packet parsing, sample reconstruction (2ms intervals), and buffer operations work correctly.

## Step 8 – Project Setup Finalization (Dev A)
Stiina

Verified Flutter SDK installation and Android build confirmation.

Configured linting via analysis_options.yaml (disabled avoid_print for development).

Updated project README with setup instructions, prerequisites, and build commands for Android/iOS.

Created project root .gitignore for shared build/IDE artifacts.

Added GitHub PR template (.github/PULL_REQUEST_TEMPLATE.md) with standard review checklist.

Validated flutter analyze passes with zero issues.

---

## Next Priorities

- **Dev C**: Implement presentation layer (ViewModels, live_ecg_screen.dart)
- **Dev B**: Domain models and storage layer  
- **Dev D**: Signal processing (filtering, R-peak detection, HR calculation)
- **All**: Physical device testing once UI framework in place
