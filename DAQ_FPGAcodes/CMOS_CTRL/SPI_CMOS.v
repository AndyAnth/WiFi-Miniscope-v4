`timescale  1ns/1ns

module  SPI_CMOS#(
    parameter   data_width = 25 ,
    parameter   data_depth = 600,
    parameter   addr_width = 12 ,
    parameter   row_depth  = 304,
    parameter   colume_width = 304
)
(
    input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    
    input   wire            ready       ,
    input   wire            sck_in      ,   //ESP32 输入的时钟信号
    
    output  wire    [24:0]  data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [26:0]  data_in     ,
    output  reg     [31:0]  data_rec    ,
    output  reg             cs_n_out_pos,   //cs_n_out在sck_out时钟下打一拍得到的
    output  wire            cs_n_out_pre,   
    output  wire            cs_n_out    ,   //片选信号
    input   wire            cs_n_in     ,
    output  reg     [2:0]   sck_out_cnt ,
    output  reg             sck_out     ,   //串行时钟
    output  reg             cs_line_set ,   //输出的数据同步使能信号
    output  reg             mosi        ,   //主输出从输入数据
    input  wire             miso        ,
    output  reg     [4:0]   cnt_bit     ,    //比特计数器
    output  reg     [5:0]   rec_cnt_bit ,
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [4:0]   sck_cnt     ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    output  reg             flag_in     ,   //FIFO读入标志信号

    output   wire  [addr_width-1:0]  wr_addr      ,
    output   wire  [addr_width-1:0]  rd_addr      

);

//parameter define
parameter   FOT           =   3'b001 ,   //帧空闲状态
            WR_EN         =   3'b010 ,   //行使能状态
            ROT           =   3'b100 ;   //行空闲状态

FIFO_CMOS#(
    .data_width (27 ),
    .data_depth (600),
    .addr_width (12 )
)FIFO_CMOS_inst
(
    .rst_n  (sys_rst_n ),
    .wr_clk (sck_in    ),
    .wr_en  (flag_in   ),
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
assign data_in = data_rec[26:0];  //多取一位为满足CMOS驱动的时序要求

//产生FIFO读入标志信号（这里暂时认为FIFO只需要一个时钟周期就可以完成数据写入）
always@(posedge sck_in or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        flag_in <= 1'b0;
    else if(rec_cnt_bit == 6'd31)       //这里依然配置成32位
        flag_in <= 1'b1;   
    else
        flag_in <= 1'b0;

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

//sck_cnt的作用是标记当前已发送多少数据，为了产生rd_clk时钟
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  5'd0;
    else if(sck_cnt == 5'd26)
        sck_cnt <=  5'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

//rd_sck是sck25分频后的时钟，指示fifo的读出周期
always@(posedge sck_out or negedge sys_rst_n)  //在sck上升沿产生rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 5'd26)   //暂时不确定是26还是27
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck_out or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <= 5'd0;
    else if(valid == 1'b1)      //时序逻辑，会晚一拍
        cnt_bit <= cnt_bit + 1'b1;
    else if(cnt_bit == 5'd26)
        cnt_bit <= 5'd0;
    else
        cnt_bit <= cnt_bit;

//mosi:两段式状态机第二段，逻辑输出
always@(posedge sck_out or negedge sys_rst_n)  
    if(sys_rst_n == 1'b0) 
        mosi <= 1'b0;
    else if(valid == 1'b1)
        mosi <= data_in[26-cnt_bit];  
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

assign cs_n_out = cs_n_out_pre & cs_n_out_pos;

endmodule