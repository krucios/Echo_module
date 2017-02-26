module servo_fsm #(parameter PWM_CYCLES_PER_ITER = 1)(
        input   wire        clk,
        input   wire        rst_n,

        // to servo_driver
        input   wire        servo_cycle_done,
        output  reg[7:0]    servo_angle = 8'h80,

        // to control unit
        input   wire        move_en,     // Enable signal for prevent movements during sonar work
        input   wire[7:0]   start_angle, // [-90   ..    90] in degrees projected to
        input   wire[7:0]   end_angle    // [8'h00 .. 8'hFF] angle reg's value
    );

    // INTERNAL REGISTERS
    reg[1:0]    state       = 0;         // FSM current state
    reg[1:0]    next_state  = 0;         // FSM next state
    parameter   WAIT_SERVO  = 2'b00;
    parameter   DIVIDE      = 2'b01;
    parameter   ANGLE_UPD   = 2'b10;
    parameter   DIR_UPD     = 2'b11;

    reg[8:0]    divider     = PWM_CYCLES_PER_ITER - 1;
    reg         servo_dir   = 0;     // 0 - increasing angle. 1 - decreasing.

     /********* Angle control process ************
     * Just changes servo angle
     * from start angle value to end angle value
     * and after this returns angle value to
     * it's start value.
     * Example: start_val = 1, end_value = 3
     * Angle sequence: 1 2 3 2 1 2 3 2 1 ...
     *******************************************/

    // Assign new state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= WAIT_SERVO;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            next_state <= WAIT_SERVO;
        end else begin
            case (state)
                WAIT_SERVO: begin
                    if (servo_cycle_done) begin
                        next_state  <= DIVIDE;
                    end
                end
                DIVIDE: begin
                    if (divider == 0 && move_en == 1) begin
                        next_state  <= ANGLE_UPD;
                    end else begin
                        next_state  <= WAIT_SERVO;
                    end
                end
                ANGLE_UPD: begin
                    next_state  <= DIR_UPD;
                end
                DIR_UPD: begin
                    next_state  <= WAIT_SERVO;
                end
            endcase
        end
    end

    // Outputs logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            divider     <= PWM_CYCLES_PER_ITER;
            servo_dir   <= 0;
            servo_angle <= 8'h80;
        end else begin
            case (state)
                WAIT_SERVO: begin
                end
                DIVIDE: begin
                    if (divider == 0) begin
                        divider <= PWM_CYCLES_PER_ITER - 1;
                    end else begin
                        divider <= divider - 1;
                    end
                end
                ANGLE_UPD: begin
                    if (servo_dir) begin
                        servo_angle <= servo_angle + 1;
                    end else begin
                        servo_angle <= servo_angle - 1;
                    end
                end
                DIR_UPD: begin
                    if (start_angle >= servo_angle ||
                        end_angle   <= servo_angle) begin
                        servo_dir <= !servo_dir;
                    end
                end
            endcase
        end
    end

endmodule
