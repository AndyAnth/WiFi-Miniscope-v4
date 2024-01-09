`timescale  1ns/1ns

module  SPI_transfer
(
    input   wire            sck       ,   //主机输入的串行时钟
    input   wire            sys_rst_n ,   //复位信号,低电平有效

    input   wire    [7:0]   data_in   ,
    input   wire            valid     ,
    input   wire            cs_n      ,

    output  reg             miso      ,   //主输出从输入数据
    output  reg     [2:0]   cnt_bit       //比特计数器     

);

//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <= 3'd0;
    else if((valid == 1'b1) && (cs_n == 1'b0))      //时序逻辑，会晚一拍
        cnt_bit <= cnt_bit + 1'b1;
    else if(cnt_bit == 3'd7)
        cnt_bit <= 3'd0;
    else
        cnt_bit <= cnt_bit;

//mosi:两段式状态机第二段，逻辑输出
always@(posedge sck or negedge sys_rst_n)  //在posedge写入，这样就能在negedge读出了
    if(sys_rst_n == 1'b0)
        miso <= 1'b0;
    else if((valid == 1'b1) && (cs_n == 1'b0))
        miso <= data_in[7-cnt_bit];    //写使能指令
    else if((valid == 1'b1) && (cs_n == 1'b1))  //时序逻辑，正常就应该再多发一位
        miso <= 1'b0;
    else
        miso <= 1'b0;

endmodule
