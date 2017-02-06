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

        // to servo_driver
        input   wire        servo_cycle_done,
        output  reg[7:0]    servo_angle = 8'h80,

        // to sonar_driver
        input   wire        sonar_ready,
        input   wire[7:0]   sonar_distance,
        output  reg         sonar_measure = 0
    );

    // Internal registers for servo control
    reg      servo_move  = 0;     // Posedge of this signal initiates moving
    reg[7:0] start_angle = 8'h80; // [-90   ..    90] in degrees projected to
    reg[7:0] end_angle   = 8'h80; // [8'h00 .. 8'hFF] angle reg's value
    reg      servo_dir   = 0;     // 0 - increasing angle. 1 - decreasing.

    // Internal registers for sonar control
    reg[7:0] distance = 0;

    // Internal registers for cmd processing
    parameter AUTO_MODE     = 1'b0;
    parameter MANUAL_MODE   = 1'b1;
    reg      mode = MANUAL_MODE;

    parameter FETCH_CMD_STATE       = 4'h0;
    parameter FETCH_DATA_STATE_PRE  = 4'h1;
    parameter FETCH_DATA_STATE      = 4'h2;
    parameter WAIT_SERVO_DONE       = 4'h3;
    parameter START_MSR_STATE       = 4'h4;
    parameter MEASURE_STATE         = 4'h5;
    parameter WAIT_TX_RDY_STATE_1   = 4'h6;
    parameter SEND_DIST_STATE       = 4'h7;
    parameter WAIT_TX_RDY_STATE_2   = 4'h8;
    parameter SEND_ANGLE_STATE      = 4'h9;
    reg[3:0] state = FETCH_CMD_STATE;

    // Cmd set
    parameter MANUAL_CMD    = 4'h0;
    // Manual cmd set
    parameter SET_ANGLE_CMD = 2'h0;
    parameter SET_MODE_CMD  = 2'h1;
    parameter MEASURE_CMD   = 2'h2;

    /********* Angle control process ************
     * Just changes servo angle
     * from start angle value to end angle value
     * and after this returns angle value to
     * it's start value.
     * Example: start_val = 1, end_value = 3
     * Angle sequence: 1 2 3 2 1 2 3 2 1 ...
     *******************************************/
    always @(posedge servo_move or negedge rst_n) begin
        if (~rst_n) begin
            servo_dir   <= 0;
            servo_angle <= 8'h80;
        end else begin
            if (servo_dir) begin
                if (servo_angle <= start_angle) begin
                    servo_dir <= !servo_dir;
                end else begin
                    servo_angle <= servo_angle - 1;
                end
            end else begin
                if (servo_angle >= end_angle) begin
                    servo_dir <= !servo_dir;
                end else begin
                    servo_angle <= servo_angle + 1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mode          <= MANUAL_MODE;
            state         <= FETCH_CMD_STATE;
            cmd_oen       <= 1;
            data_wen      <= 1;
            data          <= 0;
            sonar_measure <= 0;
            servo_move    <= 0;
            start_angle   <= 8'h80;
            end_angle     <= 8'h80;
        end else begin
            case(state)
                FETCH_CMD_STATE: begin
                    cmd_oen <= 1;
                    servo_move <= 0;
                    if (rx_rdy) begin
                        cmd_oen <= 0;
                        case (cmd[7:4])
                            MANUAL_CMD: begin // in this case
                                case (cmd[3:2])
                                    SET_ANGLE_CMD: begin
                                        state <= FETCH_DATA_STATE_PRE;
                                    end
                                    SET_MODE_CMD: begin
                                        mode <= cmd[0];
                                    end
                                    MEASURE_CMD: begin
                                        state <= WAIT_SERVO_DONE;
                                    end
                                endcase // manual cmd case
                            end
                            default: begin // In this case: [7:4] - end angle MSB, [3:0] - start angle MSB
                                start_angle <= {cmd[3:0], 4'h0};
                                end_angle   <= {cmd[7:4], 4'h0};
                                if (start_angle > end_angle) begin
                                    end_angle <= start_angle;
                                end
                                state       <= WAIT_SERVO_DONE;
                            end
                        endcase // cmd case
                    end else begin
                        if (mode == AUTO_MODE) begin    // In manual mode wait for measure cmd
                            state <= WAIT_SERVO_DONE;
                        end
                    end
                end
                FETCH_DATA_STATE_PRE: begin
                    cmd_oen <= 1;
                    state <= FETCH_DATA_STATE;
                end
                FETCH_DATA_STATE: begin
                    if (rx_rdy) begin
                        start_angle <= cmd;
                        end_angle   <= cmd;
                        cmd_oen     <= 0;
                        state       <= FETCH_CMD_STATE;
                    end
                end
                WAIT_SERVO_DONE: begin
                    cmd_oen       <= 1;
                    if (servo_cycle_done) begin
                        state <= START_MSR_STATE;
                    end
                end
                START_MSR_STATE: begin
                    sonar_measure <= 1;        // Generate measure pulse
                    state         <= MEASURE_STATE;
                end
                MEASURE_STATE: begin
                    sonar_measure <= 0;
                    if (sonar_ready) begin
                        distance    <= sonar_distance;   // Save distance
                        servo_move  <= 1;                // After measurement move servo
                        state       <= WAIT_TX_RDY_STATE_1;
                    end
                end
                WAIT_TX_RDY_STATE_1: begin
                    if (tx_rdy) begin
                        data     <= {distance[7:1], 1'b0}; // Add zero as LSB for show that it's distance byte
                        data_wen <= 0;
                        state    <= SEND_DIST_STATE;
                    end
                end
                SEND_DIST_STATE: begin
                    data_wen <= 1;
                    if (!tx_rdy) begin
                        state <= WAIT_TX_RDY_STATE_2;
                    end
                end
                WAIT_TX_RDY_STATE_2: begin
                    if (tx_rdy) begin
                        data     <= {servo_angle[7:1], 1'b1}; // Add one as LSB for show that it's angle byte
                        data_wen <= 0;
                        state    <= SEND_ANGLE_STATE;
                    end
                end
                SEND_ANGLE_STATE: begin
                    data_wen <= 1;
                    if (!tx_rdy) begin
                        state <= FETCH_CMD_STATE;
                    end
                end
            endcase // state case
        end
    end

endmodule
