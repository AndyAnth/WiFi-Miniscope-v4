`timescale  1ns/1ns

module  DAQ_sync
(
    input   wire            sys_clk     ,   //system clock 50MHz
    input   wire            sys_rst_n   ,   //??λ???,??????Ч
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

    input   wire    [2:0]   state       ,


    output  reg     [7:0]   data_in     ,
    output  reg             daq_clk     ,
    output  reg     [9:0]   rec_cnt

);

//parameter define
parameter   FOT           =   3'b001 ,   //帧使能状态
            WR_EN         =   3'b010 ,   //帧/行使能状态
            ROT           =   3'b100 ;   //行使能状态

//将pclk在sys_clk下打拍(前提是F_sys_clk > F_pclk)
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        daq_clk <= 1'b0;
    else
        daq_clk <= clk_out;
end

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

always@(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt <= 1'b0;
    else if(line_vaild == 1'b1)
        rec_cnt <= rec_cnt + 1'b1;
    //else if(frame_vaild == 1'b0)    //这里改过，原来的版本没有这个判断条件
    //    rec_cnt <= rec_cnt;     //这会导致两帧之间出现一次过长的CS拉低时间
    else
        rec_cnt <= 1'b0;
end
/*
always@(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        bit_cnt <= 1'b0;
    else if(line_vaild == 1'b1)
        bit_cnt <= bit_cnt + 1'b1;
    else
        bit_cnt <= 1'b0;
end

always@(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt_index <= 1'b0;
    else if(line_vaild == 1'b0)
        rec_cnt_index <= rec_cnt_index + 1'b1;
    else
        rec_cnt_index <= rec_cnt_index;
end

always@(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt <= 1'b0;
    else if(line_vaild == 1'b0)
        rec_cnt[rec_cnt_index] <= bit_cnt;
    else
        rec_cnt <= rec_cnt;
end
*/
endmodule