module servo_driver #(parameter freq = 50_000_000) (
        input  wire      clk,
        input  wire      rst_n,
        input  wire[7:0] angle,

        output reg       servo_pwm = 0,
        output reg       cycle_done = 0
    );

    parameter CYCLES_1_MS  = freq / 1_000;
    parameter CYCLES_19_MS = CYCLES_1_MS * 19;
    parameter CYCLES_20_MS = CYCLES_1_MS * 20;

    // INTERNAL REGISTERS
    reg[7:0]    angle_reg = 0;   // Used for storing angle
    reg[31:0]   counter = 0;     // Used for store one period
    reg[31:0]   pulse_width = 0; // Used for vary pulse width (reversed)

    reg[1:0]    state = 0;              // FSM current state
    reg[1:0]    next_state = 0;         // FSM next state
    parameter   GET_ANGLE   = 2'b00;
    parameter   GET_WIDTH   = 2'b01;
    parameter   HIGH_PULSE  = 2'b10;
    parameter   LOW_PULSE   = 2'b11;

    // Assign new state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= GET_ANGLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            next_state <= GET_ANGLE;
        end else begin
            case (state)
                GET_ANGLE: begin
                    next_state  <= GET_WIDTH;
                end
                GET_WIDTH: begin
                    next_state  <= HIGH_PULSE;
                end
                HIGH_PULSE: begin
                    if (counter == pulse_width) begin
                        next_state <= LOW_PULSE;
                    end
                end
                LOW_PULSE: begin
                    if (counter == 0) begin
                        next_state <= GET_ANGLE;
                    end
                end
            endcase
        end
    end

    // Outputs logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            servo_pwm   <= 0;
            cycle_done  <= 0;
            counter     <= 0;
            angle_reg   <= 0;
            pulse_width <= 0;
        end else begin
            case (state)
                GET_ANGLE: begin
                    angle_reg   <= angle;
                    counter     <= CYCLES_20_MS;
                end
                GET_WIDTH: begin
                    pulse_width <= CYCLES_19_MS - (angle_reg * CYCLES_1_MS) / 8'hFF;
                    servo_pwm   <= 1;
                    cycle_done  <= 1;
                end
                HIGH_PULSE: begin
                    counter    <= counter - 1;
                    cycle_done <= 0;
                    servo_pwm  <= 1;
                end
                LOW_PULSE: begin
                    counter    <= counter - 1;
                    cycle_done <= 0;
                    servo_pwm  <= 0;
                end
            endcase
        end
    end
endmodule
