`timescale  1ns/1ns

module  tb_spi_slave();

//wire  define
wire    cs_n;
reg    sck ;
wire    mosi ;

//reg   define
reg     clk     ;
reg     rst_n   ;


wire     [3:0]   state   ;   //状态机状态

wire     [2:0]   cnt_bit ;   //比特计数器

reg            data_in0    ;
reg            data_in1    ;
reg            data_in2    ;
reg            data_in3    ;
reg            data_in4    ;
reg            data_in5    ;
reg            data_in6    ;
reg            data_in7    ;

wire    [7:0]   data_out;
wire             rd_req;
wire             wr_req;
wire            rd_empty;
wire            wr_full;

reg            pclk        ;
reg            vsync       ;
reg            hsync       ;

wire             handshake_start   ;
wire             handshake_end   ;

wire    [7:0]   data_in;

wire            daq_clk;
wire  [2:0]      sck_cnt;
wire             rd_clk;

//时钟、复位信号、模拟按键信号
initial
    begin
        clk =   0;
        sck = 0;
        rst_n   <=  0;
        data_in0 <= 1;
        data_in1 <= 0;
        data_in2 <= 0;
        data_in3 <= 1;
        data_in4 <= 0;
        data_in5 <= 0;
        data_in6 <= 1;
        data_in7 <= 0;
        pclk    <= 0;
        vsync   <= 1;
        hsync   <= 0;

        #100
        rst_n   <=  1;

        #100
        vsync   <= 0;

        #2000
        vsync   <= 1;

        #200
        vsync   <= 0;

        #2000
        vsync   <= 1;

        #200
        vsync   <= 0;


        /*#1000
        data_in0 <= 1;
        data_in1 <= 0;
        data_in2 <= 1;
        data_in3 <= 0;
        data_in4 <= 1;
        data_in5 <= 0;
        data_in6 <= 1;
        data_in7 <= 0;

        #10
        #1000
        data_in0 <= 1;
        data_in1 <= 0;
        data_in2 <= 0;
        data_in3 <= 0;
        data_in4 <= 0;
        data_in5 <= 0;
        data_in6 <= 1;
        data_in7 <= 0;*/
    end

always  #10 clk <=  ~clk;
always  #140 pclk <=  ~pclk;
always  #20 sck <=  ~sck;

always  #40 data_in0 <= data_in0 + 1'b1;
always  #20 data_in1 <= data_in1 + 1'b1;
always  #30 data_in2 <= data_in2 + 1'b1;
always  #40 data_in3 <= data_in3 + 1'b1;
always  #60 data_in4 <= data_in4 + 1'b1;
always  #40 data_in5 <= data_in5 + 1'b1;
always  #20 data_in6 <= data_in6 + 1'b1;
always  #40 data_in7 <= data_in7 + 1'b1;




//-------------spi_flash_erase-------------
spi_slave    spi_slave_inst
(
    .sys_clk    (clk        ),  //系统时钟，频率50MHz
    .sys_rst_n  (rst_n      ),  //复位信号,低电平有效
    .data_in0   (data_in0   ),
    .data_in1   (data_in1   ),
    .data_in2   (data_in2   ),
    .data_in3   (data_in3   ),
    .data_in4   (data_in4   ),
    .data_in5   (data_in5   ),
    .data_in6   (data_in6   ),
    .data_in7   (data_in7   ),

    .pclk       (pclk),
    .vsync      (vsync),
    .hsync      (hsync),

    .data_out   (data_out),
    .rd_req     (rd_req),
    .wr_req     (wr_req),
    .rd_empty   (rd_empty),
    .wr_full    (wr_full),

    .data_in       (data_in       ),
    .sck        (sck        ),  //串行时钟
    .cs_n       (cs_n       ),  //片选信号
    .mosi       (mosi       ),   //主输出从输入数据
    .handshake_start  (handshake_start  ),
    .handshake_end  (handshake_end  ),
    .cnt_bit    (cnt_bit    ),
    .state      (state      ),
    .daq_clk    (daq_clk),
    .sck_cnt(sck_cnt),
    .rd_clk (rd_clk)
);


endmodule