module sonar_driver #(int freq = 50_000_000) (
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

    reg[2:0]    state      = 0;
    reg[2:0]    next_state = 0;
    parameter   IDLE       = 3'h0;
    parameter   TRIG       = 3'h1;
    parameter   WAIT_ECHO  = 3'h2;
    parameter   MEASURING  = 3'h3;
    parameter   READY      = 3'h4;

    assign distance = i_dist[31:24];

    // Assign new state logic
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state      = IDLE;
            next_state = IDLE;
        end else begin
            state = next_state;
        end
    end

    // Next state logic
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state   = IDLE;
            i_dist  = 0;
            ready   = 0;
            counter = 0;
        end else begin
            case (state)
                IDLE: begin
                    if (measure == 1) begin
                        counter     = CYCLES_10_US;
                        next_state  = TRIG;
                    end
                end
                TRIG: begin
                    if (counter == 0) begin
                        state = WAIT_ECHO;
                    end
                    counter--;
                end
                WAIT_ECHO: begin
                    if (echo == 1) begin
                        state = MEASURING;
                    end
                end
                MEASURING: begin
                    if (echo == 0) begin
                        state = READY;
                    end
                end
                READY: begin
                    state = IDLE;
                end
            endcase
        end
    end

    // Outputs logic
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            trig    = 0;
            i_dist  = 0;
            ready   = 0;
        end else begin
            case (state)
                IDLE: begin
                    ready = 0;
                end
                TRIG: begin
                    i_dist   = 0;
                    trig     = 1;
                end
                WAIT_ECHO: begin
                    trig    = 0;
                end
                MEASURING: begin
                    i_dist += NM_PER_CYCLE;
                end
                READY: begin
                    ready = 1;
                end
            endcase
        end
    end
endmodule : sonar_driver;
