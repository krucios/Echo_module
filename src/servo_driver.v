module servo_driver #(parameter freq = 50_000_000) (
        input  wire      clk,
        input  wire      rst_n,
        input  wire[7:0] angle,

        output reg       servo_pwm = 0,
        output reg       cycle_done = 0
    );

    parameter CYCLES_1_MS      = freq / 1_000;
    parameter CYCLES_PER_ANGLE = (CYCLES_1_MS * 2) / 8'hFF;
    parameter CYCLES_21u33_MS  = CYCLES_1_MS * 21 + CYCLES_1_MS / 3;
    parameter CYCLES_22_MS     = CYCLES_1_MS * 22;

    // INTERNAL REGISTERS
    reg[7:0]    angle_reg = 0;   // Used for storing angle
    reg[31:0]   counter = 0;     // Used for store one period
    reg[31:0]   pulse_width = 0; // Used for vary pulse width (reversed)

    reg[1:0]    state = 0;              // FSM current state
    reg[1:0]    next_state = 0;         // FSM next state
    parameter   GET_ANGLE  = 2'b00;
    parameter   GET_WIDTH  = 2'b01;
    parameter   HIGH_PULSE = 2'b10;
    parameter   LOW_PULSE  = 2'b11;

    // Assign new state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state = GET_ANGLE;
        end else begin
            state = next_state;
        end
    end

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            next_state = GET_ANGLE;
        end else begin
            case (state)
                GET_ANGLE: begin
                    next_state  = GET_WIDTH;
                end
                GET_WIDTH: begin
                    next_state  = HIGH_PULSE;
                end
                HIGH_PULSE: begin
                    if (counter == pulse_width) begin
                        next_state = LOW_PULSE;
                    end
                end
                LOW_PULSE: begin
                    if (counter == 0) begin
                        next_state = GET_ANGLE;
                    end
                end
            endcase
        end
    end

    // Outputs logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            servo_pwm   = 0;
            cycle_done  = 0;
            counter     = 0;
            angle_reg   = 0;
            pulse_width = 0;
        end else begin
            case (state)
                GET_ANGLE: begin
                    angle_reg   = angle;
                    cycle_done  = 1;
                    counter     = CYCLES_22_MS;
                end
                GET_WIDTH: begin
                    pulse_width = CYCLES_21u33_MS - angle_reg * CYCLES_PER_ANGLE;
                    servo_pwm   = 1;
                    cycle_done  = 0;
                end
                HIGH_PULSE: begin
                    counter    = counter - 1;
                    servo_pwm  = 1;
                end
                LOW_PULSE: begin
                    counter    = counter - 1;
                    servo_pwm  = 0;
                end
            endcase
        end
    end
endmodule
