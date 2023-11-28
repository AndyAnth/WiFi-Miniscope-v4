`timescale  1ns/1ns
module  spi_slave
(
    //input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    input   wire            data_in0    ,
    input   wire            data_in1    ,
    input   wire            data_in2    ,
    input   wire            data_in3    ,
    input   wire            data_in4    ,
    input   wire            data_in5    ,
    input   wire            data_in6    ,
    input   wire            data_in7    ,

    input   wire            pclk        ,
    input   wire            vsync       ,
    input   wire            hsync       ,
    
    //output  wire    [7:0]   data_out,
    //output  reg             rd_req,
    //output  reg             wr_req,
    //output  wire            rd_empty,
    //output  wire            wr_full,

    //output  reg    [7:0]    data_in     ,
    input   wire            cs_n        ,   //片选信号
    input   wire            sck         ,   //串行时钟
    output  reg             mosi        ,   //主输出从输入数据
    output  reg             handshake_start      //开始传输标志信号
    //output  reg             handshake_end   ,   //结束传输标志信号
    //output  reg     [2:0]   cnt_bit     ,    //比特计数器
    //output  reg     [3:0]   state       ,
    //output  reg             daq_clk     ,
    //output  reg  [2:0]      sck_cnt,
    //output  reg             rd_clk

);

//parameter define
parameter   IDLE    =   4'b0001 ,   //初始状态
            WR_EN   =   4'b0010;   //写状态

wire    [7:0]   data_out ;
reg             rd_req   ;
reg             wr_req   ;
wire            rd_empty ;
wire            wr_full  ;
reg     [7:0]   data_in  ;

reg             handshake_end; 
reg     [2:0]   cnt_bit ;
reg     [3:0]   state   ;
reg             daq_clk ;
reg     [2:0]   sck_cnt ;
reg             rd_clk  ;

wire            clk_ref;
wire            sys_clk;

wire    clkhf_en;
wire    clkhf_pu;
assign  clkhf_en = 1'b1;
assign  clkhf_pu = 1'b1;

//引出内部高速时钟
HSOSC
#(
 .CLKHF_DIV ("0b00")
) OSCInst0 (
 .CLKHFEN (clkhf_en ),
 .CLKHFPU (clkhf_pu ),
 .CLKHF   (clk_ref  )
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



//reg     daq_clk;
//
//通过pclk在sys_clk下打拍产生一个采样时钟daq_clk来保证采样时数据已经稳定
//适用条件是f_pclk < f_sys_clk
always@(posedge clk_ref or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        daq_clk <= 1'b0;
    else if((pclk == 1'b1) && (state == WR_EN))
        daq_clk <= 1'b1;
    else
        daq_clk <= 1'b0;
end

//reg  [2:0]  sck_cnt;
//reg         rd_clk;
//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  3'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 3'd7)
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//以pclk为时钟采样输入data0~7信号
always @(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        data_in <= 0;
    else begin
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

wire    valid;

//这个fifo现有的问题是启动会延迟一段时间，且会丢失起始数据
fifo_async#(
    .data_width (8),
    .data_depth (150),
    .addr_width (12)
)fifo_async_inst
(
    .rst_n  (sys_rst_n ),
    .wr_clk (daq_clk   ),
    .wr_en  (1'b1    ),
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (rd_req    ),
    .valid  (valid     ),
    .dout   (data_out  ),
    .empty  (rd_empty  ),
    .full   (wr_full   )
    );
/*
fifo	fifo_inst (
	.data    ( data_in   ),
	.rdclk   ( sck       ),
	.rdreq   ( rd_req    ),
	.wrclk   ( daq_clk   ),
	.wrreq   ( wr_req    ),
	.q       ( data_out  ),
	.rdempty ( rd_empty  ),
	.wrfull  ( wr_full   )
	);*/


//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <=  3'd0;
    else
        cnt_bit <=  cnt_bit + 1'b1;


//state:两段式状态机第一段，状态跳转
always@(posedge clk_ref or  negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        state   <=  IDLE;
        //wr_req <= 1'b0;
    end
    else begin
        state   <=  WR_EN;
        //wr_req <= 1'b1;
    end
end

always@(posedge daq_clk or  negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        wr_req <= 1'b0;
    else if(state == WR_EN)
        wr_req <= 1'b1;
    else
        wr_req <= wr_req;
end


//初始化FIFO读写使能信号，rd_req信号是状态变为IDLE的后一拍
always@(posedge clk_ref or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_req <= 1'b0;
    else if(state == WR_EN)
        rd_req <= 1'b1;
    else
        rd_req <= 1'b0;

//mosi:两段式状态机第二段，逻辑输出
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        mosi <= 1'b0;
    else if(state == WR_EN)
        mosi <= data_out[7-cnt_bit];    //写使能指令
    else if((state == WR_EN) && (rd_empty == 1'b1)) 
        mosi <= 8'b1111_1111;   //发送一个全1数据包表示摄像头传输结束
    else    if(state == IDLE)
        mosi    <=  1'b0;

//handshake_start信号(落后一个sys_clk周期，保证稳定采样)
always@(posedge clk_ref or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        handshake_start <= 1'b0;
    else if((state == WR_EN) && (cnt_bit == 3'b000))
        handshake_start <= 1'b1;
    else
        handshake_start <= 1'b0;

//handshake_end信号
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        handshake_end <= 1'b0;
    else if((state == WR_EN) && (cnt_bit == 3'b111))
        handshake_end <= 1'b1;
    else
        handshake_end <= 1'b0;


endmodule
