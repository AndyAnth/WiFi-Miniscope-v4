`timescale  1ns/1ns
module  spi_slave
(
    //input   wire            sys_clk     ,   //系统时钟，频率50MHz
    //input    wire            sys_rst_n  ,   //复位信号,低电平有效

    /*output   reg            data_out0  ,
    output   reg            data_out1  ,
    output   reg            data_out2  ,
    output   reg            data_out3  ,
    output   reg            data_out4  ,
    output   reg            data_out5  ,
    output   reg            data_out6  ,
    output   reg            data_out7  ,
    output   reg            pclk       */
    output  wire            sys_clk 

);

//wire    sys_clk;
//引出内部高速时钟
HSOSC
#(
 .CLKHF_DIV ("0b00")
) OSCInst0 (
 .CLKHFEN (  1'b1   ),
 .CLKHFPU (  1'b1   ),
 .CLKHF   ( sys_clk )
);

/*
//48MHz->50MHz Convert
PLL PLLInst0
(
    ref_clk_i   (clk_ref  ),
    rst_n_i     (sys_rst_n),
    outcore_o   (sys_clk  ),
    outglobal_o ()
);*/

/*
//handshake_end信号
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) begin
        data_out0 <= 1'b0;
        data_out1 <= 1'b0;
        data_out5 <= 1'b0;
    end
    else begin
        data_out0 <= data_out0 + 1'b1;
        data_out1 <= data_out1 + 1'b1;
        data_out5 <= data_out5 + 1'b1;
    end

always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) begin
        data_out2 <= 1'b0;
        data_out3 <= 1'b0;
        data_out4 <= 1'b0;
        data_out6 <= 1'b0;
        data_out7 <= 1'b0;
    end
    else begin
        data_out2 <= data_out2;
        data_out3 <= data_out3;
        data_out4 <= data_out4;
        data_out6 <= data_out6;
        data_out7 <= data_out7;
    end

always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pclk <= 1'b0;
    else
        pclk <= pclk + 1'b1;
*/

endmodule
