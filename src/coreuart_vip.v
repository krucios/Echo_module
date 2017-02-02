module coreuart_vip (
        input  wire         clk,
        input  wire         rst_n,

        output reg          rxrdy       = 1,
        output reg          txrdy       = 1,
        output reg[7:0]     data_out    = 8'hF3,
        input  wire         oen,
        input  wire         wen,
        input  wire[7:0]    data_in
    );

    always begin
        @ (negedge wen);
        @ (posedge clk);
        txrdy = 0;
        repeat (11) @ (posedge clk);
        txrdy = 1;
    end
endmodule : coreuart_vip
