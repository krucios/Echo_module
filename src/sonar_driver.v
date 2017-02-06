module sonar_driver #(parameter freq = 50_000_000) (
        input  wire      clk,
        input  wire      rst_n,
        input  wire      measure,
        output reg       ready      = 0,
        output wire[7:0] distance,

        // to HC-SR04
        input  wire      echo,
        output reg       trig       = 0
    );

    parameter CYCLES_10_US = freq / 100_000;
    parameter CYCLE_PERIOD = 1_000_000_000 / freq;              // in ns
    parameter SOUND_SPEED  = 343210;                            // nm/us
    parameter NM_PER_CYCLE = SOUND_SPEED * CYCLE_PERIOD / 1000; // Sound speed = 343.21 m/s.

    // INTERNAL REGISTERS
    reg[31:0] counter = 0;
    reg[31:0] i_dist  = 0;

    reg[1:0]    state = 0;              // FSM state
    parameter   IDLE       = 2'b00;
    parameter   TRIG       = 2'b01;
    parameter   WAIT_ECHO  = 2'b10;
    parameter   MEASURING  = 2'b11;

    assign distance = i_dist[31:24];

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state   = IDLE;
            i_dist  = 0;
            ready   = 0;
            trig    = 0;
            counter = 0;
        end else begin
            case (state)
                IDLE: begin
                    ready = 0;
                    if (measure == 1) begin
                        i_dist   = 0;
                        trig     = 1;
                        counter  = CYCLES_10_US;
                        state    = TRIG;
                    end else begin
                        trig    = 0;
                        counter = 0;
                    end
                end
                TRIG: begin
                    if (counter == 0) begin
                        trig    = 0;
                        state   = WAIT_ECHO;
                    end
                    counter = counter - 1;
                end
                WAIT_ECHO: begin
                    if (echo == 1) begin
                        i_dist = i_dist + NM_PER_CYCLE;
                        state = MEASURING;
                    end
                end
                MEASURING: begin
                    i_dist = i_dist + NM_PER_CYCLE;
                    if (echo == 0) begin
                        ready = 1;
                        state = IDLE;
                    end
                end
            endcase
        end
    end
endmodule
