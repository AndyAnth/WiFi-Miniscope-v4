`timescale  1ns/1ns

module  DATA_GEN#(
    parameter   CNT20_MAX  = 4,
    parameter   CNT10_MAX = 9,
    parameter   CNT5_MAX = 19,
    parameter   LINE_MAX = 100,
    parameter   FRAME_MAX = 2000
)
(
    input   wire           sys_clk     ,   //系统时钟，频率50MHz
    input   wire           sys_rst_n   ,   //复位信号,低电平有效
    
    output  reg            data_in0    ,
    output  wire           data_in1    ,
    output  reg            data_in2    ,
    output  wire           data_in3    ,
    output  reg            data_in4    ,
    output  reg            data_in5    ,
    output  wire           data_in6    ,
    output  wire           data_in7    ,
    output  reg            clk_out     ,
    output  reg            frame_vaild ,
    output  reg            line_vaild              

);

wire     clk;
pll_ip	pll_ip_inst (
	.inclk0 ( sys_clk ),
	.c0 ( clk )
	);

reg  [2:0]   cnt_20;  //5
reg  [3:0]   cnt_10;  //10
reg  [4:0]   cnt_5;   //20
reg          clk_10;
reg          clk_5;

/*20MHz时钟*/
always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_20 <= 1'b0;
    else if(cnt_20 == CNT20_MAX)  
        cnt_20 <= 1'b0;
    else
        cnt_20 <= cnt_20 + 1'b1;

always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        clk_out <= 1'b0;
    else if(cnt_20 == CNT20_MAX)  
        clk_out <= ~clk_out;
    else
        clk_out <= clk_out;

//data0 follows the 20MHz clk
always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_in0 <= 1'b0;
    else if(cnt_20 == CNT20_MAX)
        data_in0 <= ~data_in0;
    else
        data_in0 <= data_in0;

//data0 delaied one clk_out cycle to generate data1
/*always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_in1 <= 1'b0;
    else
        data_in1 <= ~data_in0;*/

assign data_in1 = ~data_in0;


/*10MHz时钟*/
always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_10 <= 1'b0;
    else if(cnt_10 == CNT10_MAX)
        cnt_10 <= 1'b0;
    else
        cnt_10 <= cnt_10 + 1'b1;

always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        clk_10 <= 1'b0;
    else if(cnt_10 == CNT10_MAX)
        clk_10 <= ~clk_10;
    else
        clk_10 <= clk_10;

//data2 follows the 10MHz clk
always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_in2 <= 1'b0;
    else if(cnt_10 == CNT10_MAX)
        data_in2 <= ~data_in2;
    else
        data_in2 <= data_in2;

//data2 delaied one clk_10 cycle to generate data3
/*always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_in3 <= 1'b0;
    else
        data_in3 <= ~data_in2;*/

assign data_in3 = ~data_in2;


/*5MHz时钟*/
always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_5 <= 1'b0;
    else if(cnt_5 == CNT5_MAX)  
        cnt_5 <= 1'b0;
    else
        cnt_5 <= cnt_5 + 1'b1;

always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        clk_5 <= 1'b0;
    else if(cnt_5 == CNT5_MAX)  
        clk_5 <= ~clk_5;
    else
        clk_5 <= clk_5;

//data4 follows the 5MHz clk
always@(posedge clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_in4 <= 1'b0;
    else if(cnt_5 == CNT5_MAX)
        data_in4 <= ~data_in4;
    else
        data_in4 <= data_in4;

//data4 delaied one clk_5 cycle to generate data5
always@(posedge clk_5 or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_in5 <= 1'b0;
    else
        data_in5 <= data_in4;

/*data6 and data7 have const levels*/
assign data_in6 = 0;
assign data_in7 = 1;

/*generate line_vaild signal*/
reg   [6:0]  line_cnt;
always@(posedge clk_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        line_cnt <= 1'b0;
    else if(line_cnt == (LINE_MAX-1))
        line_cnt <= 1'b0;
    else
        line_cnt <= line_cnt + 1'b1;

always@(posedge clk_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        line_vaild <= 1'b0;
    else if(line_cnt == (LINE_MAX-1))
        line_vaild <= ~line_vaild;
    else
        line_vaild <= line_vaild;

/*generate frame_vaild signal*/
reg   [10:0]  frame_cnt;
always@(posedge clk_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        frame_cnt <= 1'b0;
    else if(frame_cnt == (FRAME_MAX-1))
        frame_cnt <= frame_cnt;
    else
        frame_cnt <= frame_cnt + 1'b1;

always@(posedge clk_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        frame_vaild <= 1'b0;
    else if(frame_cnt == (FRAME_MAX-1))
        frame_vaild <= ~frame_vaild;
    else
        frame_vaild <= frame_vaild;


endmodule