`timescale  1ns/1ns

module  DAQ_sync
(
    input   wire            sys_clk     ,   //system clock 50MHz
    input   wire            sys_rst_n   ,   
    input   wire            data_in0    ,
    input   wire            data_in1    ,
    input   wire            data_in2    ,
    input   wire            data_in3    ,
    input   wire            data_in4    ,
    input   wire            data_in5    ,
    input   wire            data_in6    ,
    input   wire            data_in7    ,

    input   wire            clk_out     ,  //pclk
    input   wire            frame_vaild ,  //hsync
    input   wire            line_vaild  ,  //vsync

    input   wire    [2:0]    state       ,


    output  reg     [7:0]   data_in     ,
    output  wire            daq_clk    

);

//parameter define
parameter   FOT           =   3'b001 ,   //帧使能状态
            WR_EN         =   3'b010 ,   //帧/行使能状态
            ROT           =   3'b100 ;   //行使能状态


assign daq_clk = clk_out;


//在pclk打拍后的rd_sck下对data0~7进行采样
always @(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        data_in <= 0;
    end
    else if(state == WR_EN) begin
        data_in[0] <= data_in0;
        data_in[1] <= data_in1;
        data_in[2] <= data_in2;
        data_in[3] <= data_in3;
        data_in[4] <= data_in4;
        data_in[5] <= data_in5;
        data_in[6] <= data_in6;
        data_in[7] <= data_in7;
    end
end

endmodule