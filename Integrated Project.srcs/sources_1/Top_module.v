`timescale 1ns / 1ps

module Top_module (
    input         clk,
    input         reset,
    input         btn_L,
    input         btn_R,
    input         btn_C,
    input         btn_U,
    input         btn_D,
    input         i_sr_echo,
    input  [ 3:0] sw,
    input         i_uart_rx,
    output        o_uart_tx,
    output        o_sr_tirgger,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data,
    output [15:0] led,
    inout         dhtio
);

    // =========================================================
    // 1. 내부 와이어 선언부
    // =========================================================
    // 물리 버튼 출력
    wire w_btn_L, w_btn_R, w_btn_C, w_btn_U, w_btn_D;
    wire w_btn_U_level, w_btn_D_level;

    // 가상(UART) 버튼 및 스위치 펄스
    wire w_v_btn_L, w_v_btn_R, w_v_btn_C, w_v_btn_U, w_v_btn_D;
    wire w_v_sw_0, w_v_sw_1, w_v_sw_2, w_v_sw_3;

    // 컨트롤 유닛에서 나오는 시스템 최종 상태
    wire [3:0] w_final_sw;
    wire [1:0] w_display_mode; // 00:Watch, 01:Stopwatch, 10:Ultra, 11:DHT

    // 제어 및 데이터 패스 와이어
    wire w_sw_run_stop, w_sw_clear, w_sw_mode;
    wire [ 2:0] w_w_cursor;
    wire        w_w_blink_en;
    wire [ 3:0] w_blink_mask;

    wire [31:0] w_i_fnd_in_data;
    wire [ 2:0] w_dht_debug;
    wire        w_dht11_valid;
    wire [ 8:0] w_sr_dist;
    wire [15:0] w_humidity;
    wire [15:0] w_temperature;

    // UART & FIFO 통합용 와이어
    wire        w_send_trig;
    wire w_fifo_full, w_fifo_empty;
    wire w_fifo_push, w_fifo_pop;
    wire [7:0] w_fifo_push_data, w_fifo_pop_data;
    wire w_rx_done;
    wire [7:0] w_i_rx_data;
    wire w_tx_busy, w_tx_start;
    wire [7:0] w_tx_data;

    // 센서 타이머용 와이어 
    wire w_sr_start_pulse;
    wire w_dht_start_pulse;

    // =========================================================
    // 2. OR 로직: 물리 버튼 + 가상 버튼 병합
    // =========================================================
    wire final_btn_L       = w_btn_L       | w_v_btn_L;
    wire final_btn_R       = w_btn_R       | w_v_btn_R;
    wire final_btn_C       = w_btn_C       | w_v_btn_C;
    wire final_btn_U       = w_btn_U       | w_v_btn_U;
    wire final_btn_D       = w_btn_D       | w_v_btn_D;
    wire final_btn_U_level = w_btn_U_level | w_v_btn_U;
    wire final_btn_D_level = w_btn_D_level | w_v_btn_D;

    // 스톱워치 상태(w_display_mode == 2'b01)일 때는 꾹 누르는(Level) 동작 막기
    wire w_btn_U_level_gated = (w_display_mode == 2'b01) ? 1'b0 : final_btn_U_level;
    wire w_btn_D_level_gated = (w_display_mode == 2'b01) ? 1'b0 : final_btn_D_level;

    // =========================================================
    // 3. LED 할당
    // =========================================================
    assign led[15:8] = 8'h00; 
    assign led[6:4] = (w_dht_debug == 0) ? 3'd0 : 
                      (w_dht_debug == 1) ? 3'd1 :
                      (w_dht_debug == 2) ? 3'd2 :
                      (w_dht_debug == 3) ? 3'd3 :
                      (w_dht_debug == 4) ? 3'd4 : 3'd0;
    assign led[7] = w_dht11_valid ? 1 : 0;
    assign led[3:0] = 4'b0000;


    // =========================================================
    // 4. 하위 모듈 인스턴스화
    // =========================================================
    
    // --- (1) 물리 버튼 디바운서 ---
    btn U_BTN (
        .clk          (clk),
        .reset        (reset),
        .i_btn_L      (btn_L),
        .i_btn_R      (btn_R),
        .i_btn_C      (btn_C),
        .i_btn_U      (btn_U),
        .i_btn_D      (btn_D),
        .o_btn_L      (w_btn_L),
        .o_btn_R      (w_btn_R),
        .o_btn_C      (w_btn_C),
        .o_btn_U      (w_btn_U),
        .o_btn_D      (w_btn_D),
        .o_btn_U_level(w_btn_U_level),
        .o_btn_D_level(w_btn_D_level)
    );

    // --- (2) 센서 자동 시작 타이머 ---
    sensor_timer #( .TARGET_TICK(200_000_000) ) U_SENSOR_TIMER (
        .clk            (clk),
        .reset          (reset),
        .i_run_en       (w_display_mode == 2'b11), // 디스플레이 모드로 직접 제어
        .o_trigger_pulse(w_dht_start_pulse) 
    );

    sensor_timer #( .TARGET_TICK(6_000_000) ) U_SR04_TIMER (
        .clk            (clk),
        .reset          (reset),
        .i_run_en       (w_display_mode == 2'b10), // 디스플레이 모드로 직접 제어
        .o_trigger_pulse(w_sr_start_pulse) 
    );

    // --- (3) 전체 제어 허브 (우선순위 판단 로직 포함) ---
    control_unit_top U_CONTROL_UNIT_TOP (
        .clk              (clk),
        .reset            (reset),
        // 물리 및 가상 스위치 입력
        .i_sw_physical    (sw[3:0]),
        .i_v_sw_0         (w_v_sw_0),
        .i_v_sw_1         (w_v_sw_1),
        .i_v_sw_2         (w_v_sw_2),
        .i_v_sw_3         (w_v_sw_3),
        .i_btn_L          (final_btn_L),
        .i_btn_R          (final_btn_R),
        .i_btn_C          (final_btn_C),
        // 최종 결정된 시스템 상태 출력
        .o_final_sw       (w_final_sw),
        .o_display_mode   (w_display_mode),
        // 워치/센서 데이터 제어용 출력
        .o_sw_run_stop    (w_sw_run_stop),
        .o_sw_clear       (w_sw_clear),
        .o_sw_mode        (w_sw_mode),
        .o_w_cursor       (w_w_cursor),
        .o_w_blink_en     (w_w_blink_en),
        .i_sr_start       (w_sr_start_pulse),  
        .i_sr_echo        (i_sr_echo),
        .o_sr_trigger     (o_sr_tirgger),
        .o_distance       (w_sr_dist),
        .i_dht_start      (w_dht_start_pulse), 
        .o_dht_humidity   (w_humidity),
        .o_dht_temperature(w_temperature),
        .dht11_done       (),
        .dht11_valid      (w_dht11_valid),
        .debug            (w_dht_debug),
        .dhtio            (dhtio)
    );

    // --- (4) 데이터 처리 및 디스플레이부 ---
    data_path U_TOP_DP (
        .clk               (clk),
        .reset             (reset),
        .i_mode            (w_display_mode), // ★ 컨트롤러가 결정해준 최신 모드
        .i_sw_mode         (w_sw_mode),
        .i_sw_run_stop     (w_sw_run_stop),
        .i_sw_clear        (w_sw_clear),
        .i_w_cursor        (w_w_cursor),
        .i_w_btn_up_level  (w_btn_U_level_gated),
        .i_w_btn_down_level(w_btn_D_level_gated),
        .i_blink_en        (w_w_blink_en),
        .o_blink_mask      (w_blink_mask),
        .i_sr_dist         (w_sr_dist),
        .i_dht_data        ({w_humidity[15:8], w_temperature[15:8]}),
        .o_fnd_data        (w_i_fnd_in_data)
    );

    FND_CNTL #(
        .BIT_WIDTH(3)
    ) U_FND_CNTL (
        .clk         (clk),
        .reset       (reset),
        .sel_display (w_final_sw[1]), // 컨트롤러가 결정해준 포맷
        .i_count     (w_i_fnd_in_data),
        .i_blink_mask(w_blink_mask),
        .fnd_digit   (fnd_digit),
        .fnd_data    (fnd_data)
    );

    // --- (5) UART 통신부 ---
    ascii_decoder ASCII_DECODER (
        .clk        (clk),
        .reset      (reset),
        .i_rx_done  (w_rx_done),
        .i_rx_data  (w_i_rx_data),
        .o_btn_L    (w_v_btn_L),
        .o_btn_R    (w_v_btn_R),
        .o_btn_C    (w_v_btn_C),
        .o_btn_U    (w_v_btn_U),
        .o_btn_D    (w_v_btn_D),
        .o_sw_0     (w_v_sw_0),
        .o_sw_1     (w_v_sw_1),
        .o_sw_2     (w_v_sw_2),
        .o_sw_3     (w_v_sw_3),
        .o_sw_4     (), // 사용 안함
        .o_send_trig(w_send_trig)
    );

    ascii_sender U_ASCII_SENDER (
        .clk         (clk),
        .reset       (reset),
        .i_send_trig (w_send_trig),
        .i_fifo_full (w_fifo_full),
        .i_sw_dht    (w_display_mode == 2'b11),
        .i_sw_ultra  (w_display_mode == 2'b10),
        .i_sw_stw    (w_display_mode == 2'b01),
        .i_byte3     (w_i_fnd_in_data[31:24]),
        .i_byte2     (w_i_fnd_in_data[23:16]),
        .i_byte1     (w_i_fnd_in_data[15:8]),
        .i_byte0     (w_i_fnd_in_data[7:0]),
        .o_push_data (w_fifo_push_data),
        .o_push      (w_fifo_push),
        .o_is_sending()
    );

    // --- (6)  FIFO 및 TX 인터페이스 ---
    Top_FIFO #(
        .Data_Width(8),
        .Address_Depth(32)
    ) U_TOP_FIFO (
        .clk    (clk),
        .rst    (reset),
        .i_push (w_fifo_push),
        .i_pop  (w_fifo_pop),
        .i_data (w_fifo_push_data),
        .o_data (w_fifo_pop_data),
        .o_full (w_fifo_full),
        .o_empty(w_fifo_empty)
    );

    fifo_uart_fsm U_FIFO_FSM (
        .clk            (clk),
        .reset          (reset),
        .i_fifo_empty   (w_fifo_empty),
        .i_fifo_pop_data(w_fifo_pop_data),
        .o_fifo_pop     (w_fifo_pop),
        .i_rx_data      (w_i_rx_data),
        .i_rx_done      (w_rx_done),
        .i_tx_busy      (w_tx_busy),
        .o_tx_data      (w_tx_data),
        .o_tx_start     (w_tx_start)
    );

    UART_Top_Module U_UART_TOP (
        .clk       (clk),
        .reset     (reset),
        .i_tx_data (w_tx_data),
        .i_tx_start(w_tx_start),
        .i_uart_rx (i_uart_rx),
        .o_uart_tx (o_uart_tx),
        .o_rx_data (w_i_rx_data),
        .o_rx_done (w_rx_done),
        .o_tx_busy (w_tx_busy)
    );

endmodule