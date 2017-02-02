module sonar_vip #(int freq = 50_000_000) (
        input  wire      clk,
        input  wire      rst_n,

        // to DUT
        output reg      echo = 0,
        input  wire     trig
    );

    parameter CYCLE_PERIOD = 1_000_000_000 / freq;              // in ns
    parameter SOUND_SPEED  = 343210;                            // nm/us
    parameter NM_PER_CYCLE = SOUND_SPEED * CYCLE_PERIOD / 1000; // Sound speed = 343.21 m/s.

    // INTERNAL REGISTERS
    reg[31:0] counter = 0;

    reg[1:0]    state = 0;              // FSM state
    parameter   IDLE       = 2'b00;
    parameter   TRIG       = 2'b01;
    parameter   RANDOMIZE  = 2'b10;
    parameter   SEND_ECHO  = 2'b11;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state       = IDLE;
            echo        = 0;
            counter     = 0;
        end else begin
            case (state)
                IDLE: begin
                    if (trig == 1) begin
                        state   = TRIG;
                    end
                end
                TRIG: begin
                    if (trig == 0) begin
                        state = RANDOMIZE;
                    end
                end
                RANDOMIZE: begin
                    counter = ($urandom() % 1500 + 10) * 2 * 1_000_000 / NM_PER_CYCLE;
                    $display($sformatf("Distance length: %d clocks", counter));
                    echo = 1;
                    state = SEND_ECHO;
                end
                SEND_ECHO: begin
                    counter--;
                    if (counter == 0) begin
                        echo = 0;
                        state = IDLE;
                    end
                end
            endcase
        end
    end
endmodule : sonar_vip;
