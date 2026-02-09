package 'Final_Interceptor_Architecture' {
    import ISQ::*;
    import ScalarValues::*;
    
    // -------------------------------------------------------------------------
    // 1. DATA TYPES (The Language)
    // -------------------------------------------------------------------------
    
    enum def PACE_Mode {
        :>> Primary_Intercept;
        :>> Alternate_Coast;
        :>> Contingency_Search;
        :>> Emergency_FTS;
    }

    struct def TargetState {
        attribute azimuth : AngleValue;
        attribute elevation : AngleValue;
        attribute az_Rate : AngularVelocityValue; // Velocity
        attribute el_Rate : AngularVelocityValue; // Velocity
        attribute az_Accel : AngularAccelerationValue; // NEW: For curved coasting
    }

    // -------------------------------------------------------------------------
    // 2. SIGNAL PROCESSING (The Filter)
    // -------------------------------------------------------------------------

    part def OpticalSensor {
        attribute raw_data : TargetState;
    }

    part def Advanced_Estimator {
        // Extended Kalman Filter (EKF) Logic
        // Estimates Position, Velocity, AND Acceleration
        
        in input : TargetState;

        action predict_coast_path {
            in last_known_state : TargetState;
            in dt : TimeValue;
            out predicted_pos : AngleValue;
            
            // Logic: pos = pos + (vel * dt) + (0.5 * acc * dt^2)
            // This allows the drone to "lead" the target even while blind.
        }
    }
    
    part def Power_Distribution_Architecture {
        in servo_cmd : AngleValue;
    }

    part def Proportional_Nav_Direct {
        out fin_cmd : AngleValue;
    }

    // -------------------------------------------------------------------------
    // 3. DECISION LOGIC (The Brain)
    // -------------------------------------------------------------------------

    part def PACE_Manager {
        // Inputs
        in confidence : Real;
        in battery_ok : Boolean;
        
        // Output for Arbitration
        out active_mode : PACE_Mode;
        
        // Internal State Variables
        attribute sequential_good_frames : Integer = 0;
        attribute time_since_lock : TimeValue = 0.0 [s];
        
        // Hysteresis Constants
        attribute lock_threshold : Real = 0.90;
        attribute reengage_threshold : Real = 0.95; // Harder to re-enter than to stay
        attribute frames_required : Integer = 5; // Must see 5 good frames to lock

        // State Machine
        state def Mode_Logic {
            entry; then Check_System_Health;

            state Check_System_Health {
                transition on !battery_ok then Emergency_FTS;
                transition then Check_Tracker;
            }

            state Check_Tracker {
                // Hysteresis: Only transition to Primary if we have sustained lock
                transition on (confidence > lock_threshold) && (sequential_good_frames > frames_required) then Primary_Intercept;
                
                // Degraded Logic
                transition on time_since_lock < 2.0 [s] then Alternate_Coast;
                transition on time_since_lock >= 2.0 [s] then Contingency_Search;
            }

            state Primary_Intercept {
                entry assign active_mode = PACE_Mode::Primary_Intercept;
                entry assign sequential_good_frames = sequential_good_frames + 1;
                entry assign time_since_lock = 0.0 [s];
                
                // Exit condition: Instant drop to Alternate if lock lost
                transition on confidence < lock_threshold then Alternate_Coast;
            }

            state Alternate_Coast {
                entry assign active_mode = PACE_Mode::Alternate_Coast;
                entry assign sequential_good_frames = 0;
                // Accumulate time
                
                // Re-engagement: Must meet stricter criteria to jump back
                transition on (confidence > reengage_threshold) then Primary_Intercept;
                transition on time_since_lock > 2.0 [s] then Contingency_Search;
            }

            state Contingency_Search {
                entry assign active_mode = PACE_Mode::Contingency_Search;
                // Loiter pattern.
                // If we miraculously find the target again:
                transition on (confidence > 0.98) then Primary_Intercept;
            }
            
            state Emergency_FTS {
                entry assign active_mode = PACE_Mode::Emergency_FTS;
                // Terminal State
            }
        }
    }

    // -------------------------------------------------------------------------
    // 4. INTEGRATED SYSTEM (The Product)
    // -------------------------------------------------------------------------

    part 'Interceptor_mk1' {
        // --- COMPONENTS ---
        part sensor_suite : OpticalSensor;
        part estimator : Advanced_Estimator;
        part computer : PACE_Manager;
        part guidance : Proportional_Nav_Direct;
        part plant : Power_Distribution_Architecture;

        // --- CONNECTIVITY ---
        
        // Flow: Sensor -> Estimator -> Guidance -> Plant
        // The PACE Manager sits on top, gating the signals.
        
        connect sensor_suite.raw_data to estimator.input;
        
        // The Guidance block receives State from Estimator
        // BUT, the PACE Manager tells the Plant *which* command to listen to.
        
        action arbitration {
            in mode : PACE_Mode = computer.active_mode;
            in nav_sol : AngleValue = guidance.fin_cmd;
            in coast_sol : AngleValue = estimator.predict_coast_path.predicted_pos; 
            
            out final_servo_cmd : AngleValue;
            
            // Mixing Logic
            // Psuedocode for the arbitration action:
            // if (mode == Primary_Intercept) final_servo_cmd = nav_sol;
            // else if (mode == Alternate_Coast) final_servo_cmd = coast_sol; // Use prediction
            // else final_servo_cmd = 0 [deg]; // Neutral or Loiter bank
        }
        
        connect arbitration.final_servo_cmd to plant.servo_cmd;
    }
}
