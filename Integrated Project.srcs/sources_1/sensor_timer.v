`timescale 1ns / 1ps

module sensor_timer #(
    parameter TARGET_TICK = 200_000_000 // 기본값: 100MHz 기준 2초
) (
    input  clk,
    input  reset,
    input  i_run_en,       // 제어부에서 오는 동작 허가 신호 (Toggle 상태)
    output o_trigger_pulse // 센서 구동용 시작 펄스
);

    reg [27:0] timer_cnt;
    wire w_max_tick = (timer_cnt == TARGET_TICK - 1);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            timer_cnt <= 0;
        end else if (i_run_en) begin
            if (w_max_tick) timer_cnt <= 0;
            else            timer_cnt <= timer_cnt + 1;
        end else begin
            timer_cnt <= 0; // 정지 시 초기화
        end
    end

    // 동작 중이며 목표 시간에 도달했을 때 딱 1클록만 High가 됨
    assign o_trigger_pulse = (i_run_en && w_max_tick);

endmodule