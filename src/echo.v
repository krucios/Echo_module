module echo (
        input   wire        clk,
        input   wire        rst_n,

        // to CoreUART
        input   wire        rxrdy,
        input   wire        txrdy,
        input   wire[7:0]   data_out,
        output  wire        oen,
        output  wire        wen,
        output  wire[7:0]   data_in,

        // to SG90
        output  wire        servo_pwm,

        // to HC-SR04
        input  wire      echo,
        output wire      trig
    );

    wire[7:0] servo_angle;
    wire      servo_cycle_done;
    wire[7:0] sonar_distance;
    wire      sonar_measure;
    wire      sonar_ready;


    servo_driver servo(
            .clk(clk),
            .rst_n(rst_n),
            .servo_pwm(servo_pwm),
            .angle(servo_angle),
            .cycle_done(servo_cycle_done)
        );

    sonar_driver sonar(
            .clk(clk),
            .rst_n(rst_n),
            .echo(echo),
            .trig(trig),
            .measure(sonar_measure),
            .ready(sonar_ready),
            .distance(sonar_distance)
        );

    control_unit cu(
            .clk(clk),
            .rst_n(rst_n),
            .cmd(data_out),
            .cmd_oen(oen),
            .data(data_in),
            .data_wen(wen),
            .rx_rdy(rxrdy),
            .tx_rdy(txrdy),
            .servo_angle(servo_angle),
            .servo_cycle_done(servo_cycle_done),
            .sonar_distance(sonar_distance),
            .sonar_measure(sonar_measure),
            .sonar_ready(sonar_ready)
        );
endmodule
