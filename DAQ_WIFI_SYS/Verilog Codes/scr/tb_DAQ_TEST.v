`timescale  1ns/1ns

module  tb_DAQ_TEST#(
    parameter   CNT20_MAX  = 4,
    parameter   CNT10_MAX = 9,
    parameter   CNT5_MAX = 19,
    parameter   LINE_MAX = 100,
    parameter   FRAME_MAX = 2000
);

reg            sys_clk     ;
reg            sys_rst_n   ;
wire           data_in0    ;
wire           data_in1    ;
wire           data_in2    ;
wire           data_in3    ;
wire           data_in4    ;
wire           data_in5    ;
wire           data_in6    ;
wire           data_in7    ;
wire           clk_out     ;
wire           frame_vaild ;
wire           line_vaild  ;

initial
    begin
        sys_clk    = 0;
        sys_rst_n  = 0;

        #50
        sys_rst_n  = 1;
    end

always  #10 sys_clk  <=  ~sys_clk;

DATA_GEN#(
    .CNT20_MAX  (4   ),
    .CNT10_MAX  (9   ),
    .CNT5_MAX   (19  ),
    .LINE_MAX   (100 ),
    .FRAME_MAX  (2000)
) DATA_GEN_inst
(
    .sys_clk     (sys_clk),   //系统时钟，频率50MHz
    .sys_rst_n   (sys_rst_n),   //复位信号,低电平有效

    .data_in0    (data_in0),
    .data_in1    (data_in1),
    .data_in2    (data_in2),
    .data_in3    (data_in3),
    .data_in4    (data_in4),
    .data_in5    (data_in5),
    .data_in6    (data_in6),
    .data_in7    (data_in7),
    .clk_out     (clk_out),
    .frame_vaild (frame_vaild),
    .line_vaild  (line_vaild)
);


endmodule
