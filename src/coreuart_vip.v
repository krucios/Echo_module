module coreuart_vip (
        input  wire         clk,
        input  wire         rst_n,

        output reg          rxrdy       = 0,
        output reg          txrdy       = 1,
        output reg[7:0]     data_out    = 8'hF3,
        input  wire         oen,
        input  wire         wen,
        input  wire[7:0]    data_in
    );

    // Transmit stub
    always begin
        @ (negedge wen);
        @ (posedge clk);
        txrdy = 0;
        repeat (11) @ (posedge clk);
        txrdy = 1;
    end

    // Receive stub
    always begin
        int delay = $urandom() % 100 + 100;
        $display($sformatf("Chosen delay: %d clocks", delay));
        #(delay * 1ms);
        @(posedge clk);
        rxrdy = 1;
        data_out = $urandom();
        $display($sformatf("Random data from UART: %h", data_out));
        while (oen) @(posedge clk);
        @(posedge clk);
        rxrdy = 0;
    end
endmodule : coreuart_vip
