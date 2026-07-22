`timescale 1ns / 1ps

module ascii_sender (
    input clk,
    input reset,
    input i_send_trig,
    input i_fifo_full,   // UART 바쁨 대기 -> FIFO Full 체크로 변경

    // 모드 스위치
    input i_sw_dht,
    input i_sw_ultra,
    input i_sw_stw,

    // data_path에서 나온 32비트 (8bit 4개)
    input [7:0] i_byte3,
    input [7:0] i_byte2,
    input [7:0] i_byte1,
    input [7:0] i_byte0,

    output reg [7:0] o_push_data,  // FIFO 데이터
    output reg       o_push,       // FIFO Push 신호
    output           o_is_sending
);
    localparam IDLE = 2'b00;
    localparam SEND = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [4:0] char_idx;
    reg [4:0] msg_len;

    // 보낼 문자열을 담을 buffer 
    reg [7:0] char_buf [0:15];
    assign o_is_sending = (state != IDLE);
    
    // 십의 자리 수 분리. 90 넘거나 같으면 9, 90보다 작고 80보다 크거나 같으면 8...
    function [3:0] get_tens;
        input [7:0] bin;
        begin
            if (bin >= 8'd90) get_tens = 4'd9;
            else if (bin >= 8'd80) get_tens = 4'd8;
            else if (bin >= 8'd70) get_tens = 4'd7;
            else if (bin >= 8'd60) get_tens = 4'd6;
            else if (bin >= 8'd50) get_tens = 4'd5;
            else if (bin >= 8'd40) get_tens = 4'd4;
            else if (bin >= 8'd30) get_tens = 4'd3;
            else if (bin >= 8'd20) get_tens = 4'd2;
            else if (bin >= 8'd10) get_tens = 4'd1;
            else get_tens = 4'd0;
        end
    endfunction
    
    // 일의 자리 수 분리. 90넘으면 90을 빼고, 90보다 작고 80보다 크거나 같으면 80빼고...
    function [3:0] get_ones;
        input [7:0] bin;
        begin
            if (bin >= 8'd90) get_ones = bin - 8'd90;
            else if (bin >= 8'd80) get_ones = bin - 8'd80;
            else if (bin >= 8'd70) get_ones = bin - 8'd70;
            else if (bin >= 8'd60) get_ones = bin - 8'd60;
            else if (bin >= 8'd50) get_ones = bin - 8'd50;
            else if (bin >= 8'd40) get_ones = bin - 8'd40;
            else if (bin >= 8'd30) get_ones = bin - 8'd30;
            else if (bin >= 8'd20) get_ones = bin - 8'd20;
            else if (bin >= 8'd10) get_ones = bin - 8'd10;
            else get_ones = bin[3:0];
        end
    endfunction
    // =========================================================

    // 1. 상태 및 인덱스 제어 (순차 로직)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            char_idx <= 0;
            msg_len <= 0;
        end else begin
            case (state)
                IDLE: begin
                    char_idx <= 0;
                    if (i_send_trig) begin
                        if (i_sw_dht) begin
                            // [DHT 모드]
                            char_buf[0] <= "H";
                            char_buf[1] <= "U";
                            char_buf[2] <= "M";
                            char_buf[3] <= ":";
                            char_buf[4] <= 8'h30 + get_tens(i_byte3); 
                            char_buf[5] <= 8'h30 + get_ones(i_byte3);
                            char_buf[6] <= " ";
                            char_buf[7] <= "T";
                            char_buf[8] <= "M";
                            char_buf[9] <= "P";
                            char_buf[10] <= ":";
                            char_buf[11] <= 8'h30 + get_tens(i_byte2);
                            char_buf[12] <= 8'h30 + get_ones(i_byte2);
                            char_buf[13] <= 8'h0D; 
                            char_buf[14] <= 8'h0A; 
                            msg_len <= 15;
                            state <= SEND;
                        end else if (i_sw_ultra) begin
                            // 초음파 모드
                            char_buf[0] <= "D";
                            char_buf[1] <= "I";
                            char_buf[2] <= "S";
                            char_buf[3] <= "T";
                            char_buf[4] <= ":";
                            char_buf[5] <= 8'h30 + i_byte3;
                            char_buf[6] <= 8'h30 + get_tens(i_byte2);
                            char_buf[7] <= 8'h30 + get_ones(i_byte2);
                            char_buf[8] <= 8'h0D;
                            char_buf[9] <= 8'h0A;
                            msg_len <= 10;
                            state <= SEND;
                        end else if (i_sw_stw) begin
                            // 스톱워치 모드
                            char_buf[0] <= "S";
                            char_buf[1] <= "T";
                            char_buf[2] <= "W";
                            char_buf[3] <= ":";
                            char_buf[4] <= 8'h30 + get_tens(i_byte2);
                            char_buf[5] <= 8'h30 + get_ones(i_byte2);
                            char_buf[6] <= ":";
                            char_buf[7] <= 8'h30 + get_tens(i_byte1);
                            char_buf[8] <= 8'h30 + get_ones(i_byte1);
                            char_buf[9] <= ":";
                            char_buf[10] <= 8'h30 + get_tens(i_byte0);
                            char_buf[11] <= 8'h30 + get_ones(i_byte0);
                            char_buf[12] <= 8'h0D;
                            char_buf[13] <= 8'h0A;
                            msg_len <= 14;
                            state <= SEND;
                        end else begin
                            // 시계 모드
                            char_buf[0] <= "W";
                            char_buf[1] <= "T";
                            char_buf[2] <= "C";
                            char_buf[3] <= ":";
                            char_buf[4] <= 8'h30 + get_tens(i_byte3);
                            char_buf[5] <= 8'h30 + get_ones(i_byte3);
                            char_buf[6] <= ":";
                            char_buf[7] <= 8'h30 + get_tens(i_byte2);
                            char_buf[8] <= 8'h30 + get_ones(i_byte2);
                            char_buf[9] <= ":";
                            char_buf[10] <= 8'h30 + get_tens(i_byte1);
                            char_buf[11] <= 8'h30 + get_ones(i_byte1);
                            char_buf[12] <= 8'h0D;
                            char_buf[13] <= 8'h0A;
                            msg_len <= 14;
                            state <= SEND;
                        end
                    end
                end

                SEND: begin
                    // 꽉 차지 않았을 때만 인덱스를 올리거나 DONE으로 넘어감
                    if (!i_fifo_full) begin
                        if (char_idx == msg_len - 1) begin
                            state <= DONE;
                        end else begin
                            char_idx <= char_idx + 1;
                        end
                    end
                    // 꽉 차 있으면 아무 동작도 하지 않고 대기(Hold)
                end

                DONE: begin
                    state  <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // 2. 출력 제어 (조합 로직)
    // 딜레이 없이 꽉 차지 않았을 때 즉시 o_push=1과 데이터를 뱉어냄
    always @(*) begin
        if (state == SEND && !i_fifo_full) begin
            o_push = 1'b1;
            o_push_data = char_buf[char_idx];
        end else begin
            o_push = 1'b0;
            o_push_data = 8'h00;
        end
    end

endmodule