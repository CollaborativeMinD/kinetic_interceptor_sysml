# Autonomous Kinetic Interceptor (SysML v2)

### PACE-Hardened Guidance, Navigation, and Control (GNC) Architecture for Counter-UAS.

![SysML v2](https://img.shields.io/badge/Language-SysML_v2-blue)
![TRL](https://img.shields.io/badge/TRL-4-orange)
![Status](https://img.shields.io/badge/Status-Verified-brightgreen)

## Executive Summary

This repository contains the authoritative system architecture for a high-velocity kinetic interceptor drone (DIU-Blue-UAS Class). Unlike traditional "Happy Path" architectures, this design implements a **PACE-Hardened** fault tolerance strategy. It features autonomous **"Curved Coasting"** (Predictive Guidance) to maintain intercept trajectories even when optical locks are lost due to sun glare or occlusion.

Critical safety features include **Brownout Protection**, which throttles propulsion to preserve avionics voltage during high-G maneuvers, and a **Latent-Aware Guidance Loop** tuned to account for the calculated ~196ms sensor-to-fin latency stack.

## Key Features

* **PACE Architecture:** A robust state machine governing **P**rimary (Intercept), **A**lternate (Coast), **C**ontingency (Search), and **E**mergency (Termination) modes.
* **Hysteresis Logic:** "Sticky" state transitions that prevent mode flickering during edge-case sensor saturation (e.g., oscillating between 89% and 91% confidence).
* **Predictive "Blind" Guidance:** Utilizes an Extended Kalman Filter (EKF) to estimate target acceleration (`az_Accel`), allowing the drone to continue a curved intercept path during temporary sensor blindness.
* **Safety Critical Isolation:** Distinct logic gates for Flight Termination Systems (FTS) based on battery criticality (<18V) or Geofence breaches.

## State Transition Logic (PACE)

```mermaid
stateDiagram-v2
    [*] --> Check_Systems
    
    state Check_Systems {
        [*] --> Check_Battery
        Check_Battery --> Check_Sensor: Voltage > 18V
        Check_Battery --> Emergency_FTS: Voltage < 18V
    }

    state Operational_Modes {
        Check_Sensor --> Primary_Intercept: Conf > 90%
        Check_Sensor --> Alternate_Coast: Conf < 90%
        
        Primary_Intercept --> Alternate_Coast: Loss of Lock
        
        Alternate_Coast --> Primary_Intercept: Re-acquire (Conf > 95%)
        Alternate_Coast --> Contingency_Search: Timeout (> 2.0s)
        
        Contingency_Search --> Primary_Intercept: Miracle Lock (> 98%)
    }

    Operational_Modes --> Emergency_FTS: Geofence Breach
    Emergency_FTS --> [*]: Terminate
