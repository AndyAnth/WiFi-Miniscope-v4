`timescale  1ns/1ns

module  tb_DAQ_SPI#(
    parameter   data_width = 8,
    parameter   package_size = 2000
);

reg            sys_clk      ;   //系统时钟，频率50MHz
reg            sys_rst_n    ;   //复位信号,低电平有效
wire    [7:0]  data_out    ;
wire           rd_empty    ;
wire           wr_full     ;
wire    [7:0]  data_in     ;
reg            cs_n        ;   //片选信号
reg            sck         ;   //串行时钟
wire           miso        ;   //主输出从输入数据
wire    [2:0]  cnt_bit     ;    //比特计数器
wire    [2:0]  state       ;
wire           daq_clk     ;
wire    [2:0]  sck_cnt     ;
wire           start_trans ;
wire           valid       ;
wire           rd_clk      ;
wire           intr_out    ;
wire           package_ready;
wire           clk_out;
wire           pre_delay_flag;
wire           pos_delay_flag;

initial
    begin
        sys_clk    = 0;
        sys_rst_n  = 0;
        sck        = 0;
        cs_n       = 1;

        #50
        sys_rst_n  = 1;
        cs_n       = 0;

        #3000

        cs_n = 1;

        #500
        cs_n = 0;
        
        #3000
        cs_n = 1;
    end

always  #10 sys_clk  <=  ~sys_clk;
always  #20 sck  <=  ~sck;

Sys#(
    .data_width     (8   ),
    .package_size   (10)
)Sys_inst
(
    .sys_clk     (sys_clk    ),   //系统时钟，频率50MHz
    .sys_rst_n   (sys_rst_n  ),   //复位信号,低电平有效

    .data_out    (data_out   ),
    .rd_empty    (rd_empty   ),
    .wr_full     (wr_full    ),

    .data_in     (data_in    ),
    .cs_n        (cs_n       ),   //片选信号
    .sck         (sck        ),   //串行时钟
    .miso        (miso       ),   //主输出从输入数据
    .cnt_bit     (cnt_bit    ),    //比特计数器
    .state       (state      ),
    .daq_clk     (daq_clk    ),
    .sck_cnt     (sck_cnt    ),
    .start_trans (start_trans),
    .valid       (valid      ),
    .rd_clk      (rd_clk     ),
    .package_ready(package_ready),
    .clk_out     (clk_out    ),
    .pre_delay_flag (pre_delay_flag),
    .pos_delay_flag (pos_delay_flag),
    .intr_out    (intr_out   )

);

endmodule