module control_unit (
        input   wire        clk,
        input   wire        rst_n,

        // to UART receiver
        input   wire[7:0]   cmd,
        input   wire        rx_rdy,
        input   wire        tx_rdy,
        output  reg         cmd_oen     = 1,
        output  reg         data_wen    = 1,
        output  reg[7:0]    data        = 0,

        // to servo fsm
        input   wire[7:0]   servo_angle, // [-90   ..    90] in degrees projected to
        output  reg[7:0]    start_angle, // [8'h00 .. 8'hFF] angle reg's value
        output  reg[7:0]    end_angle,

        // to servo driver
        input   wire        servo_cycle_done,

        // to sonar_driver
        input   wire        sonar_ready,
        input   wire[7:0]   sonar_distance,
        output  reg         sonar_measure = 0
    );

    // Internal registers for sonar control
    reg[7:0] distance = 0;

    // Internal registers for cmd processing
    parameter AUTO_MODE     = 1'b0;
    parameter MANUAL_MODE   = 1'b1;
    reg       mode          = AUTO_MODE;

    parameter IDLE            = 4'h0;
    parameter FETCH_CMD       = 4'h1;
    parameter FETCH_DATA_PRE  = 4'h2;
    parameter FETCH_DATA      = 4'h3;
    parameter WAIT_SERVO_DONE = 4'h4;
    parameter START_MEASURE   = 4'h5;
    parameter MEASURE         = 4'h6;
    parameter WAIT_TX_RDY     = 4'h7;
    parameter SEND_DATA       = 4'h8;
    reg[3:0]  state      = IDLE;
    reg[3:0]  next_state = IDLE;

    reg       send_data_type = 0; // 0 - distance; 1 - angle;

    // Cmd set
    parameter MANUAL_CMD    = 4'h0;
    // Manual cmd set
    parameter SET_ANGLE_CMD = 2'h0;
    parameter SET_MODE_CMD  = 2'h1;
    parameter MEASURE_CMD   = 2'h2;

    // Assign new state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            next_state    <= IDLE;
        end else begin
            case(state)
                IDLE: begin
                    if (rx_rdy) begin
                        next_state <= FETCH_CMD;
                    end else if (mode == AUTO_MODE) begin    // In manual mode wait for measure cmd
                        next_state <= WAIT_SERVO_DONE;
                    end
                end
                FETCH_CMD: begin
                    case (cmd[7:4])
                        MANUAL_CMD: begin // in this case
                            case (cmd[3:2])
                                SET_ANGLE_CMD: begin
                                    next_state <= FETCH_DATA_PRE;
                                end
                                SET_MODE_CMD: begin
                                    next_state <= IDLE;
                                end
                                MEASURE_CMD: begin
                                    next_state <= START_MEASURE;
                                end
                            endcase // manual cmd case
                        end
                        default: begin // In this case: [7:4] - end angle MSB, [3:0] - start angle MSB
                            next_state <= IDLE;
                        end
                    endcase // cmd case
                end
                FETCH_DATA_PRE: begin
                    if (rx_rdy) begin
                        next_state <= FETCH_DATA;
                    end
                end
                FETCH_DATA: begin
                    next_state <= IDLE;
                end
                WAIT_SERVO_DONE: begin
                    if (servo_cycle_done) begin
                        next_state <= START_MEASURE;
                    end
                end
                START_MEASURE: begin
                    next_state <= MEASURE;
                end
                MEASURE: begin
                    if (sonar_ready) begin
                        next_state <= WAIT_TX_RDY;
                    end
                end
                WAIT_TX_RDY: begin
                    if (tx_rdy) begin
                        next_state <= SEND_DATA;
                    end
                end
                SEND_DATA: begin
                    if (~tx_rdy) begin
                        case(send_data_type)
                            0: next_state <= WAIT_TX_RDY;
                            1: next_state <= IDLE;
                        endcase
                    end
                end
            endcase // state case
        end
    end

    // Outputs logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mode          <= AUTO_MODE;
            cmd_oen       <= 1;
            data_wen      <= 1;
            data          <= 0;
            sonar_measure <= 0;
            start_angle   <= 8'h00;
            end_angle     <= 8'hFF;
        end else begin
            case(state)
                IDLE: begin
                    cmd_oen       <= 1;
                    data_wen      <= 1;
                    sonar_measure <= 0;
                end
                FETCH_CMD: begin
                    cmd_oen <= 0;
                    case (cmd[7:4])
                        MANUAL_CMD: begin // in this case
                            case (cmd[3:2])
                                SET_MODE_CMD: begin
                                    mode <= cmd[0];
                                end
                            endcase // manual cmd case
                        end
                        default: begin // In this case: [7:4] - end angle MSB, [3:0] - start angle MSB
                            if (cmd[3:0] < cmd[7:4]) begin
                                start_angle <= {cmd[3:0], 4'h0};
                                end_angle   <= {cmd[7:4], 4'h0};
                            end else begin
                                start_angle <= {cmd[7:4], 4'h0};
                                end_angle   <= {cmd[3:0], 4'h0};
                            end
                        end
                    endcase // cmd case
                end
                FETCH_DATA_PRE: begin
                    cmd_oen <= 1;
                end
                FETCH_DATA: begin
                    start_angle <= cmd;
                    end_angle   <= cmd;
                    cmd_oen     <= 0;
                end
                WAIT_SERVO_DONE: begin

                end
                START_MEASURE: begin
                    sonar_measure <= 1; // Generate measure pulse
                end
                MEASURE: begin
                    sonar_measure <= 0;
                    distance      <= sonar_distance;
                end
                WAIT_TX_RDY: begin
                    data_wen <= 1;
                end
                SEND_DATA: begin
                    data_wen        <= 0;
                    send_data_type  <= !send_data_type;
                    case(send_data_type)
                        0: data     <= {distance[7:1], 1'b0}; // Add zero as LSB for show that it's distance byte
                        1: data     <= {servo_angle[7:1], 1'b1}; // Add one as LSB for show that it's angle byte
                    endcase
                end
            endcase
        end
    end

endmodule
