`timescale 1ns / 1ps

module Top_FIFO #(
    parameter Data_Width = 8,
    parameter Address_Depth = 4
)(
    input                       clk,
    input                       rst,
    input                       i_push,
    input                       i_pop,
    input      [Data_Width-1:0] i_data,
    output wire [Data_Width-1:0] o_data,
    output wire                 o_full,
    output wire                 o_empty
);

    // 내부 연결용 와이어
    // MSB가 포함된 포인터를 받기 위한 와이어 (Address_Depth 크기 + 1비트)
    wire [$clog2(Address_Depth):0] w_wptr_full;
    wire [$clog2(Address_Depth):0] w_rptr_full;
    
    // 컨트롤 모듈이 허락한 안전한 쓰기 신호
    wire w_we;

    fifo_register #(
        .Data_Width(Data_Width),
        .Address_Depth(Address_Depth)
    ) U_FIFO_REG (
        .clk        (clk),
        .we         (w_we), 
        // 컨트롤에서 온 포인터 중 최상위 비트(MSB)를 버리고, 하위 비트(실제 주소)만 잘라서 연결
        .write_addr (w_wptr_full[$clog2(Address_Depth)-1:0]),
        .read_addr  (w_rptr_full[$clog2(Address_Depth)-1:0]),
        .i_data     (i_data),
        .o_data     (o_data)
    );

    fifo_control #(
        .Address_Depth(Address_Depth)
    ) U_FIFO_CNTL (
        .clk        (clk),
        .rst        (rst),
        .i_push     (i_push),
        .i_pop      (i_pop),
        .o_wptr     (w_wptr_full),
        .o_rptr     (w_rptr_full),
        .o_full     (o_full),   // Top 모듈 출력으로 바로 연결
        .o_empty    (o_empty),  // Top 모듈 출력으로 바로 연결
        .o_we       (w_we)      // 메모리의 we로 들어갈 안전한 신호 연결
    );

endmodule