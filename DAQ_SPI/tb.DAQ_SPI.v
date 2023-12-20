`timescale  1ns/1ns

module  tb_DAQ_SPI#(
    parameter   data_width = 8,
    parameter   data_depth = 1000,
    parameter   addr_width = 14,
    parameter   package_size = 1000
);

reg            sys_clk     ;   //系统时钟，频率50MHz
reg            sys_rst_n   ;   //复位信号,低电平有效
wire    [7:0]  data_out    ;

wire    [7:0]  data_in     ;
reg            cs_n        ;   //片选信号
reg            sck         ;   //串行时钟
wire           miso        ;   //主输出从输入数据

reg            monitor     ;

wire           intr_out    ;

wire           data_in0    ;
wire           data_in1    ;
wire           data_in2    ;
wire           data_in3    ;
wire           data_in4    ;
wire           data_in5    ;
wire           data_in6    ;
wire           data_in7    ;
wire           clk_out     ;  //像素同步信号
wire           frame_vaild ;  //帧同步信号
wire           line_vaild  ;  //行同步信号

wire           status_led  ;
wire           monitor_led ;
wire           package_ready;

wire           valid       ;
wire           rd_clk      ;
wire           rd_en       ;
wire           rd_out      ;
wire           daq_clk     ;
wire [addr_width-1:0]  rd_addr1;
wire [addr_width-1:0]  wr_addr1;
wire [addr_width-1:0]  wr_addr2;
wire [addr_width-1:0]  rd_addr2;
wire            rd_en1     ;
wire            full1      ;
wire            full2      ;
wire            wr_en1     ;
wire            wr_en2     ;

wire            ram_wr_sel;
wire            ram1_rd_sel;
wire            ram2_rd_sel;

DATA_GEN#(
    .CNT20_MAX  ( 4  ),
    .CNT10_MAX  ( 9  ),
    .CNT5_MAX   ( 19 ),
    .LINE_MAX   (100 ),
    .FRAME_MAX  (50)
) DATA_GEN_inst
(
    .sys_clk     (sys_clk    ),   //系统时钟，频率50MHz
    .sys_rst_n   (sys_rst_n  ),   //复位信号,低电平有效

    .data_in0    (data_in0   ),
    .data_in1    (data_in1   ),
    .data_in2    (data_in2   ),
    .data_in3    (data_in3   ),
    .data_in4    (data_in4   ),
    .data_in5    (data_in5   ),
    .data_in6    (data_in6   ),
    .data_in7    (data_in7   ),
    .clk_out     (clk_out    ),
    .frame_vaild (frame_vaild),
    .line_vaild  (line_vaild )
);

initial
    begin
        sys_clk    = 0;
        sys_rst_n  = 0;
        sck        = 0;
        cs_n       = 1;

        #50
        sys_rst_n  = 1;
        #30  monitor = 1;
        cs_n       = 0;
/*
        #3000

        cs_n = 1;

        #500
        cs_n = 0;
        
        #3000
        cs_n = 1;*/
    end

always  #10 sys_clk  <=  ~sys_clk;
always  #2 sck  <=  ~sck;

Sys#(
    .data_width     (data_width  ),
    .data_depth     (data_depth  ),
    .addr_width     (addr_width  ),
    .package_size   (package_size)
)Sys_inst
(
    .sys_clk     (sys_clk    ),   //系统时钟，频率50MHz
    .sys_rst_n   (sys_rst_n  ),   //复位信号,低电平有效

    .data_in0    (data_in0   ),
    .data_in1    (data_in1   ),
    .data_in2    (data_in2   ),
    .data_in3    (data_in3   ),
    .data_in4    (data_in4   ),
    .data_in5    (data_in5   ),
    .data_in6    (data_in6   ),
    .data_in7    (data_in7   ),
    .clk_out     (clk_out    ),
    .frame_vaild (frame_vaild),
    .line_vaild  (line_vaild ),
    .monitor     (monitor    ),
    .data_out    (data_out   ),

    .data_in     (data_in    ),
    .cs_n        (1'b0       ),   //片选信号
    .sck         (sck        ),   //串行时钟
    .miso        (miso       ),   //主输出从输入数据
    .status_led  (status_led ),
    .monitor_led (monitor_led),
    .intr_out    (intr_out   ),
    .package_ready(package_ready),
    .valid       (valid  ),
    .rd_clk      (rd_clk ),
    .rd_en       (rd_en  ),
    .rd_out      (rd_out ),
    .daq_clk     (daq_clk),
    .rd_addr1     (rd_addr1),
    .wr_addr1     (wr_addr1),
    .wr_addr2     (wr_addr2),
    .rd_addr2     (rd_addr2),

    .rd_en1      (rd_en1),
    .full1       (full1),
    .full2       (full2),
    .wr_en1      (wr_en1),
    .wr_en2      (wr_en2),
    .ram_wr_sel  (ram_wr_sel),
    .ram1_rd_sel (ram1_rd_sel),
    .ram2_rd_sel (ram2_rd_sel)
);

endmodule