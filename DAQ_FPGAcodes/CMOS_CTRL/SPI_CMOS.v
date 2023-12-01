`timescale  1ns/1ns

module  SPI_CMOS#(
    parameter   data_width = 32 ,
    parameter   data_depth = 20,
    parameter   addr_width = 5
)
(
    input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    
    input   wire            ready       ,
    input   wire            sck_in      ,   //ESP32 输入的时钟信号
    
    output  wire    [31:0]  data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [31:0]  data_in     ,
    output  reg     [31:0]  data_rec    ,
    output  reg             cs_n_out_pos,   //cs_n_out在sck_out时钟下打一拍得到的
    output  wire            cs_n_out_pre,   
    output  reg             cs_n_out    ,   //片选信号
    input   wire            cs_n_in     ,
    output  reg     [2:0]   sck_out_cnt ,
    output  reg             sck_out     ,   //串行时钟
    output  reg             mosi        ,   //主输出从输入数据
    input   wire            miso        ,
    output  reg     [5:0]   cnt_bit     ,    //比特计数器
    output  reg     [5:0]   rec_cnt_bit ,
    output  reg     [5:0]   sck_cnt     ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    output  reg             flag_in     ,   //FIFO读入标志信号
    //output  reg     [4:0]   rd_en_cnt   ,   //在每次CMOS SPI周期后空出来三个时钟周期的计数信号
    output  reg             ready_edge  ,   //检测ready信号的上升沿
    output  reg     [5:0]   cs_out_cnt  ,

    output   wire  [addr_width-1:0]  wr_addr   ,
    output   wire  [addr_width-1:0]  rd_addr     

);

FIFO_CMOS#(
    .data_width (data_width ),
    .data_depth (data_depth ),
    .addr_width (addr_width )
)FIFO_CMOS_inst
(
    .rst_n  (sys_rst_n ),
    .wr_clk (sck_in    ),
    .wr_en  (flag_in   ),   //不清楚FIFO的写入时长是多久
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (ready     ),  //ready信号是ESP32传来指示可以开始CMOS控制信号传输的握手信号
    .valid  (valid     ),
    .dout   (data_out  ),
    .empty  (rd_empty  ),
    .full   (wr_full   ),
    .wr_addr(wr_addr   ),
    .rd_addr(rd_addr   )
    );

/*数据写入FIFO*/
//首先接收32位数据：000000(6bits) + address(9bits) + w/r(1bit) + data(16bits)
//cnt_bit:高低位对调，控制mosi输入
always@(posedge sck_in or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        rec_cnt_bit <= 6'd0;
    else if(cs_n_in == 1'b0)      
        rec_cnt_bit <= rec_cnt_bit + 1'b1;
    else if(rec_cnt_bit == 6'd31)
        rec_cnt_bit <= 6'd0;
    else
        rec_cnt_bit <= rec_cnt_bit;

//SPI接收信号逻辑(首先接收32bits数据)
always@(posedge sck_in or negedge sys_rst_n)  
    if(sys_rst_n == 1'b0) 
        data_rec <= 1'b0;
    else if(cs_n_in == 1'b0)
        data_rec[31-rec_cnt_bit] <= miso;   
    else
        data_rec <= data_rec;

//将32bits数据中的冗余去掉，转变为26bits
assign data_in = {data_rec[27:0],data_rec[31:28]};  //多取一位为满足CMOS驱动的时序要求

//产生FIFO读入标志信号（这里暂时认为FIFO只需要一个时钟周期就可以完成数据写入）
always@(posedge sck_in or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        flag_in <= 1'b0;
    else if(rec_cnt_bit == 6'd31)       //这里依然配置成32位
        flag_in <= 1'b1;   
    else
        flag_in <= 1'b0;

/*产生CMOS SPI的SCK时钟信号*/
//CMOS控制SPI的时钟信号计数器
always@(posedge sys_clk or negedge sys_rst_n)  
    if(sys_rst_n == 1'b0) 
        sck_out_cnt <= 1'b0;
    else if(sck_out_cnt == 3'd4)
        sck_out_cnt <= 1'b0;
    else
        sck_out_cnt <= sck_out_cnt + 1'b1;  

//CMOS控制SPI的时钟信号(SCK)(对系统时钟信号五分频10MHz)
always@(posedge sys_clk or negedge sys_rst_n)  
    if(sys_rst_n == 1'b0) 
        sck_out <= 1'b0;
    else if(sck_out_cnt == 3'd4)
        sck_out <= ~sck_out;
    else
        sck_out <= sck_out;

/*ready信号上升沿检测逻辑*/
reg     ready_pre;
always @(posedge sck_out or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        ready_pre <= 1'b0;
    else
        ready_pre <= ready;
end
//检测ready信号的上升沿
always @(posedge sck_out or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        ready_edge <= 1'b0;
    else if((ready_pre == 1'b0) && (ready == 1'b1))  //检测上升沿
        ready_edge <= 1'b1;
    else
        ready_edge <= 1'b0;
end 

//sck_cnt的作用是标记当前已发送多少数据，为了产生rd_clk时钟
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  6'd0;
    else if((sck_cnt == 6'd31) || (ready_edge == 1'b1))  //在ready信号来临时马上开始一次传输并且清空计数器
        sck_cnt <=  6'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

/*生成cs_n_out信号*/
//dout的实际有效信号只有前28位(前两位是为了满足时序要求)，最后5位第一位是空发的一位以满足CMOS时序，最后3位留作空当
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cs_out_cnt <=  6'd0;
    else if((cs_out_cnt == 5'd31) || (ready_edge == 1'b1))
        cs_out_cnt <=  6'd0;
    else
        cs_out_cnt <=  cs_out_cnt + 1'b1;

always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cs_n_out <=  1'b1;
    else if(cs_out_cnt == 5'd27) 
        cs_n_out <=  1'b1;
    else if((rd_clk == 1'b1) && (valid == 1'b1))
        cs_n_out <=  1'b0;
    else
        cs_n_out <=  cs_n_out;

/*
//rd_en_cnt:为了在每个CMOS SPI传输后加入一段空闲时间（三个时钟周期）
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        rd_en_cnt <= 5'd0;
    else if(rd_en_cnt == 5'd29)
        rd_en_cnt <= 5'd0;
    else if(ready == 1'b1)     
        rd_en_cnt <= rd_en_cnt + 1'b1;
    else
        rd_en_cnt <= rd_en_cnt;

//rd_sck是sck25分频后的时钟，指示fifo的读出周期
always@(posedge sck_out or negedge sys_rst_n)  //在sck上升沿产生rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if((ready_edge == 1'b1) || (rd_en_cnt == 5'd26)) //在ready信号来临时马上开始一次传输
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;*/

//rd_sck是sck25分频后的时钟，指示fifo的读出周期
always@(posedge sck_out or negedge sys_rst_n)  //在sck上升沿产生rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if((ready_edge == 1'b1) || (sck_cnt == 6'd31)) //在ready信号来临时马上开始一次传输
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_bit <= 6'd0;
    else if(cnt_bit == 6'd31)
        cnt_bit <= 6'd0;
    else if(valid == 1'b1)      //时序逻辑，会晚一拍
        cnt_bit <= cnt_bit + 1'b1;
    else
        cnt_bit <= cnt_bit;

//mosi:两段式状态机第二段，逻辑输出
always@(negedge sck_out or negedge sys_rst_n)  
    if(sys_rst_n == 1'b0) 
        mosi <= 1'b0;
    else if(valid == 1'b1)
        mosi <= data_out[31-cnt_bit];  
    else
        mosi <= 1'b0; 

//输出CS片选信号，随着valid产生
assign cs_n_out_pre = ~ valid; 

//将cs_n_out信号打一拍
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cs_n_out_pos <= 1'b0;
    else   
        cs_n_out_pos <= cs_n_out_pre;

//assign cs_n_out = cs_n_out_pre & cs_n_out_pos;

endmodule