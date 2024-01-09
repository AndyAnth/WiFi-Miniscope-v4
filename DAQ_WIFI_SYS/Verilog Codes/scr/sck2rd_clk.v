module sck2rd_clk(
    input   wire    sck,
    input   wire    sys_rst_n,

    output  reg     rd_clk
);

reg     [2:0]   sck_cnt     ;
//sck_cnt的作用是标记当前已发送多少数据，为了产生rd_clk时钟
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  2'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

//rd_sck是sck八分频后的时钟，指示fifo的读出周期
always@(posedge sck or negedge sys_rst_n)  //在sck上升沿产生rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 3'd7)
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;
        
endmodule