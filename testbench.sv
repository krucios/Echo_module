`timescale 1ns/1ps

module top();
    parameter freq = 50_000_000;
    parameter period = 1s / freq;
    parameter hperiod = period / 2;

    wire clk;
    wire rst_n;

    // Sonar wires
    wire sonar_echo;
    wire sonar_trig;
    // UART wires
    wire[7:0] uart_data_in;
    wire[7:0] uart_data_out;
    wire uart_oen;
    wire uart_wen;
    wire uart_rxrdy;
    wire uart_txrdy;
    // Servo wires
    wire servo_pwm;

    reg clk_reg = 0;
    reg rst_n_reg = 1;

    assign clk = clk_reg;
    assign rst_n = rst_n_reg;

    // Clock block
    always begin
        #hperiod;
        clk_reg = !clk_reg;
    end

    // Reset block
    initial begin
        #50ns;
        rst_n_reg = 0;
        #1us;
        rst_n_reg = 1;
    end

    echo dut(
            .clk(clk),
            .rst_n(rst_n),
            .echo(1'b0),
            // .echo(sonar_echo),
            .trig(sonar_trig),
            .data_in(uart_data_in),
            .data_out(uart_data_out),
            .oen(uart_oen),
            .wen(uart_wen),
            .rxrdy(uart_rxrdy),
            .txrdy(uart_txrdy),
            .servo_pwm(servo_pwm)
        );

    sonar_vip sonar_vip(
            .clk(clk),
            .rst_n(rst_n),
            .echo(sonar_echo),
            .trig(sonar_trig)
        );

    coreuart_vip uart_vip(
            .clk(clk),
            .rst_n(rst_n),
            .data_in(uart_data_in),
            .data_out(uart_data_out),
            .oen(uart_oen),
            .wen(uart_wen),
            .rxrdy(uart_rxrdy),
            .txrdy(uart_txrdy)
        );

    initial begin
        $dumpvars;
        $dumpfile ("dump.vcd");
    end
endmodule : top
