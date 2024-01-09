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

DATA_INC_GEN#(
    .CNT_CLK_2MHZ_MAX (24)   ,
    .CNT_MAX          (12160)
)DATA_INC_GEN_INST
(
    .sys_clk     (sys_clk        ),
    .rst_n       (sys_rst_n      ),
    .data_out0   (data_out0  ) ,
    .data_out1   (data_out1  ) ,
    .data_out2   (data_out2  ) ,
    .data_out3   (data_out3  ) ,
    .data_out4   (data_out4  ) ,
    .data_out5   (data_out5  ) ,
    .data_out6   (data_out6  ) ,
    .data_out7   (data_out7  ) ,
    .clk_out     (clk_out_out    ) ,
    .frame_vaild (frame_vaild_out) ,
    .line_vaild  (line_vaild_out )  
);


endmodule
