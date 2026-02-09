# Operational Resilience Logic (CONOPS)

This document defines the autonomous decision-making logic for the Kinetic Interceptor. The system prioritizes **Safety** > **Mission** > **Platform**.

## 1. PACE Modes (Primary, Alternate, Contingency, Emergency)

The interceptor operates in one of four distinct modes based on sensor confidence and system health.

| Mode | Trigger Condition | Behavior | Logic |
| :--- | :--- | :--- | :--- |
| **Primary (Intercept)** | **Optical Confidence > 90%** AND **5+ Sequential Frames** | **Full Aggression.** Proportional Navigation (PN) guidance is active. Max throttle. | "Happy Path." The sensor sees the drone clearly. We are closing for the kill. |
| **Alternate (Coast)** | **Confidence < 90%** (Glare, Cloud, Obstruction) | **Blind Predictive Guidance.** EKF uses last known Velocity/Accel to predict target path. | "Don't Give Up." Targets often disappear for <1s. Maintain the turn; do not fly straight. |
| **Contingency (Search)** | **Lost Lock > 2.0 Seconds** | **Loiter Pattern.** Pitch up +15°, Bank 30°. Scan the horizon. | "Reset." The intercept failed. Gain altitude and try to re-acquire (requires >98% confidence). |
| **Emergency (FTS)** | **Battery < 18V** OR **Geofence Breach** | **Flight Termination.** Cut Motor (0% Throttle). Deploy Parachute (if equipped). | "Save the Ground." The platform is unsafe. Kinetic energy must be dumped immediately. |

## 2. Brownout Protection Logic

High-performance interceptors often crash not because of guidance failure, but because high-G maneuvers draw so much current that the voltage sags, rebooting the Flight Computer.

### The Mechanism
The `Power_Distribution_Architecture` implements a **Voltage-Priority Control Loop**:

1.  **Monitor:** The system samples battery voltage at 100Hz.
2.  **Threshold:** If Voltage drops below `19.8V` (3.3V/cell under load).
3.  **Action:** The `Brownout_Manager` overrides the throttle channel.
    * **Throttle Scaling:** Reduces motor power by 50%.
    * **Priority:** Current is reserved for the **Servos** and **Avionics**.

**Rationale:** You can survive 0.5 seconds without thrust (momentum carries you), but you cannot survive 0.5 seconds without fin control (tumbling) or a rebooting CPU (total loss of control).
