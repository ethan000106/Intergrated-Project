`timescale 1ns / 1ps

module control_unit_top (
    input        clk,
    input        reset,
    
    // --- 물리 스위치 및 가상 스위치 입력 ---
    input  [3:0] i_sw_physical,
    input        i_v_sw_0,
    input        i_v_sw_1,
    input        i_v_sw_2,
    input        i_v_sw_3,
    
    // --- 통합된 버튼 입력 ---
    input        i_btn_L,
    input        i_btn_R,
    input        i_btn_C,
    
    // --- 시스템 통합 상태 출력 ---
    output [3:0] o_final_sw,
    output [1:0] o_display_mode, // 00:Watch, 01:Stopwatch, 10:Ultra, 11:DHT
    
    // --- stopwatch_watch 제어 ---
    output       o_sw_run_stop,
    output       o_sw_clear,
    output       o_sw_mode,
    output [2:0] o_w_cursor,
    output       o_w_blink_en,
    
    // --- sr04 센서 제어 ---
    input        i_sr_start,
    input        i_sr_echo,
    output       o_sr_trigger,
    output [8:0] o_distance,
    
    // --- dht11 센서 제어 ---
    input        i_dht_start,
    output [15:0] o_dht_humidity,
    output [15:0] o_dht_temperature,
    output       dht11_done,
    output       dht11_valid,
    output [2:0] debug,
    inout        dhtio
);

    // =========================================================
    //  Last-Action-Wins (최신 조작 우선 로직) 
    // =========================================================
    reg [3:0] r_sw_curr, r_sw_prev, r_final_sw;
    reg [1:0] r_display_mode;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_sw_curr      <= 4'b0;
            r_sw_prev      <= 4'b0;
            r_final_sw     <= 4'b0;
            r_display_mode <= 2'b00;
        end else begin
            r_sw_curr <= i_sw_physical;
            r_sw_prev <= r_sw_curr;

            // [SW 0, 1]: 카운트 방향 및 화면 디스플레이 포맷 제어
            if (r_sw_curr[0] != r_sw_prev[0]) r_final_sw[0] <= r_sw_curr[0];
            else if (i_v_sw_0) r_final_sw[0] <= ~r_final_sw[0];

            if (r_sw_curr[1] != r_sw_prev[1]) r_final_sw[1] <= r_sw_curr[1];
            else if (i_v_sw_1) r_final_sw[1] <= ~r_final_sw[1];

            // [SW 2]: 시간 모드 제어 및 화면 갱신
            if (r_sw_curr[2] != r_sw_prev[2]) begin
                r_final_sw[2]  <= r_sw_curr[2];
                r_display_mode <= {1'b0, r_sw_curr[2]};
            end else if (i_v_sw_2) begin
                r_final_sw[2]  <= ~r_final_sw[2];
                r_display_mode <= {1'b0, ~r_final_sw[2]};
            end

            // [SW 3]: 센서 모드 제어 및 화면 갱신
            if (r_sw_curr[3] != r_sw_prev[3]) begin
                r_final_sw[3]  <= r_sw_curr[3];
                r_display_mode <= {1'b1, r_sw_curr[3]};
            end else if (i_v_sw_3) begin
                r_final_sw[3]  <= ~r_final_sw[3];
                r_display_mode <= {1'b1, ~r_final_sw[3]};
            end
        end
    end

    // 외부로 통합된 상태 전달
    assign o_final_sw = r_final_sw;
    assign o_display_mode = r_display_mode;


    // =========================================================
    // 하위 모듈 인스턴스화
    // =========================================================
    SR04_controller U_SRO4_CNRL (
        .clk         (clk),
        .reset       (reset),
        .i_sr_start  (i_sr_start),
        .i_sr_echo   (i_sr_echo),
        .o_sr_trigger(o_sr_trigger),
        .o_distance  (o_distance)
    );

    dht11_controller U_DHT11_CNRL (
        .clk              (clk),
        .reset            (reset), // (수정) 포트 이름 일치 확인 필요
        .i_dht_start      (i_dht_start),
        .o_dht_humidity   (o_dht_humidity),
        .o_dht_temperature(o_dht_temperature),
        .dht11_done       (dht11_done),
        .dht11_valid      (dht11_valid),
        .debug            (debug),
        .dhtio            (dhtio)
    );

    watch_stw_control_unit U_WATCH_STW_CTRL (
        .clk                 (clk),
        .reset               (reset),
        .i_sw_watch_stopwatch(r_final_sw[2]), // 통합된 스위치 사용
        .i_sw_up_down        (r_final_sw[0]), // 통합된 스위치 사용
        .i_btn_L             (i_btn_L),
        .i_btn_R             (i_btn_R),
        .i_btn_C             (i_btn_C),
        .o_sw_run_stop       (o_sw_run_stop),
        .o_sw_clear          (o_sw_clear),
        .o_sw_mode           (o_sw_mode),
        .o_w_cursor          (o_w_cursor),
        .o_w_blink_en        (o_w_blink_en)
    );

endmodule