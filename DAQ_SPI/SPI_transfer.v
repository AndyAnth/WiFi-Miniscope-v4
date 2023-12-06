`timescale  1ns/1ns

module  SPI_transfer
(
    input   wire            sck         ,   //主机输入的串行时钟
    input   wire            sys_rst_n   ,   //复位信号,低电平有效

    input   wire    [7:0]   data_in     ,
    //input   wire            start_trans ,
    input   wire            valid ,
    input   wire            cs_set,
    input   wire            cs_n,
    //input   wire            cs_set_pre,

    output  reg             miso        ,   //主输出从输入数据
    output  reg     [2:0]   cnt_bit     ,    //比特计数器     
    output  reg     [15:0]   sent_cnt
    //output  reg   [3:0]  duty_cnt,
    //output  reg     state_flag

);

        
/*在这里边想怎么在cs_set_pre下让数据空闲一拍*/

//reg   [3:0]  duty_cnt;   //用来计一共发了多少个周期

/*为了保证高电平持续一段时间，再设置一个状态标志*/
//reg     state_flag;

/*
always@(posedge cs_set or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        duty_cnt <= 4'd0;
    else if(duty_cnt == 4'd8)    //时序逻辑，会晚一拍
        duty_cnt <= 4'd0;
    else
        duty_cnt <= duty_cnt + 1'b1;

always@(negedge cs_set or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        state_flag <= 4'd0;
    else if(duty_cnt == 4'd8)      //时序逻辑，会晚一拍
        state_flag <= 4'd1;
    //else if(duty_cnt == 4'd5)   //这个数是模拟的，具体的数是
    //    state_flag <= 4'd0;
    else
        state_flag <= 4'd0;
*/

//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <= 3'd0;
    //else if(start_trans == 1'b1)
    else if((valid == 1'b1) /*&& (cs_set == 1'b0)*/ && (cs_n == 1'b0))      //时序逻辑，会晚一拍
        cnt_bit <= cnt_bit + 1'b1;
    else if(cnt_bit == 3'd7)
        cnt_bit <= 3'd0;
    else
        cnt_bit <= cnt_bit;

//mosi:两段式状态机第二段，逻辑输出
always@(posedge sck or negedge sys_rst_n)  //在posedge写入，这样就能在negedge读出了
    if(sys_rst_n == 1'b0) begin
        miso <= 1'b0;
        sent_cnt <= 1'b0;
    end
    //else if(start_trans == 1'b1)
    else if((valid == 1'b1) /*&& (cs_set == 1'b0)*/ && (cs_n == 1'b0)) begin
        miso <= data_in[7-cnt_bit];    //写使能指令
        sent_cnt <= sent_cnt + 1'b1;
    end
    else if((valid == 1'b1) /*&& (cs_set == 1'b1)*/ && (cs_n == 1'b1))  //时序逻辑，正常就应该再多发一位
        miso <= 1'b0;
    else
        miso <= 1'b0;

endmodule
