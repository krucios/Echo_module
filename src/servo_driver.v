module servo_driver #(int freq = 50_000_000) (
        input  wire      clk,
        input  wire      rst_n,
        input  wire[7:0] angle,

        output reg       servo_pwm = 0
    );

    parameter CYCLES_1_MS  = freq / 1000;
    parameter CYCLES_19_MS = CYCLES_1_MS * 19;
    parameter CYCLES_20_MS = CYCLES_1_MS * 20;

    // INTERNAL REGISTERS
    reg[7:0]    angle_reg = 0;   // Used for storing angle
    reg[31:0]   counter = 0;     // Used for store one period
    reg[31:0]   pulse_width = 0; // Used for vary pulse width (reversed)

    reg[1:0]    state = 0;              // FSM state
    parameter   IDLE        = 2'b00;
    parameter   GET_WIDTH   = 2'b01;
    parameter   HIGH_PULSE  = 2'b10;
    parameter   LOW_PULSE   = 2'b11;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state       = IDLE;
            counter     = 0;
            angle_reg   = 0;
            pulse_width = 0;
            servo_pwm = 0;
        end else begin
            case (state)
                IDLE: begin
                    state       = GET_WIDTH;
                    angle_reg   = angle;
                    counter     = CYCLES_20_MS;
                end
                GET_WIDTH: begin
                    pulse_width = CYCLES_19_MS - (angle_reg * CYCLES_1_MS) / 8'hFF;
                    servo_pwm = 1;
                    state       = HIGH_PULSE;
                end
                HIGH_PULSE: begin
                    counter--;
                    if (counter < pulse_width) begin
                        servo_pwm = 0;
                        state = LOW_PULSE;
                    end
                end
                LOW_PULSE: begin
                    counter--;
                    if (counter == 0) begin
                        state = IDLE;
                    end
                end
            endcase
        end
    end
endmodule : servo_driver;
