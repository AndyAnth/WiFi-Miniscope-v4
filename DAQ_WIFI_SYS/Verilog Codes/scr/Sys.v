`timescale  1ns/1ns

module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 11552,
    parameter   addr_width = 14,
    parameter   package_size = 11552
)
(
    input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    input   wire            data_in0    ,
    input   wire            data_in1    ,
    input   wire            data_in2    ,
    input   wire            data_in3    ,
    input   wire            data_in4    ,
    input   wire            data_in5    ,
    input   wire            data_in6    ,
    input   wire            data_in7    ,

    input   wire            clk_out     ,  //像素同步信号
    input   wire            frame_vaild ,  //帧同步信号
    input   wire            line_vaild  ,  //行同步信号

    input   wire            monitor     ,   //状态监视输入信号

    output  wire    [7:0]   data_out    ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,
    input   wire            sck         ,   //串行时钟
    output  wire            miso        ,   //主输出从输入数据

    output  wire            status_led  ,   //状态指示灯，package_ready置起
    output  wire            monitor_led ,   //曝光LED，收monitor控制

    output  wire            intr_out    ,

    output   wire           data_out0    ,
    output   wire           data_out1    ,
    output   wire           data_out2    ,
    output   wire           data_out3    ,
    output   wire           data_out4    ,
    output   wire           data_out5    ,
    output   wire           data_out6    ,
    output   wire           data_out7    ,

    output   wire           clk_out_out    ,  //像素同步信号
    output   wire           frame_vaild_out,  //帧同步信号
    output   wire           line_vaild_out ,   //行同步信号 

    output   wire           cs_n_out   ,      //片选信号
    output   wire           wr_en      ,
    output   wire           package_ready,
    output   wire           valid       ,
    output   wire           rd_clk      ,
    output   wire           rd_en       ,
    output   wire           rd_out      ,
    output   wire           daq_clk     ,
    output   wire [addr_width-1:0]  rd_addr1 ,
    output   wire [addr_width-1:0]  wr_addr1 ,
    output   wire [addr_width-1:0]  wr_addr2 ,
    output   wire [addr_width-1:0]  rd_addr2 ,
    output   wire            rd_en1     ,
    output   wire            full1  ,
    output   wire            full2  ,
    output   wire            wr_en1 ,
    output   wire            wr_en2 ,
    output   wire            ram_wr_sel,
    output   wire            ram1_rd_sel,
    output   wire            ram2_rd_sel,
    input    wire            data_gen_rst
    
);

wire    [2:0]   cnt_bit      ;   //比特计数器
wire    [2:0]   state        ;
wire            empty        ;
wire            empty1       ;
wire            empty2       ;
wire            rd_en2       ;
wire            rd_sel       ;
wire            valid1       ;
wire            valid2       ;
wire            emp_sel      ;
wire [data_width-1:0]  dout1 ;
wire [data_width-1:0]  dout2 ;  

DATA_INC_GEN#(
    .CNT_CLK_2MHZ_MAX (19)   ,
    .CNT_CLK_4MHZ_MAX (9)    ,
    .CNT_MAX          (12160)
)DATA_INC_GEN_INST
(
    .sys_clk     (sys_clk    ),
    .rst_n       (sys_rst_n  ),
    .data_out0   (data_out0  ) ,
    .data_out1   (data_out1  ) ,
    .data_out2   (data_out2  ) ,
    .data_out3   (data_out3  ) ,
    .data_out4   (data_out4  ) ,
    .data_out5   (data_out5  ) ,
    .data_out6   (data_out6  ) ,
    .data_out7   (data_out7  ) ,
    .clk_out     (clk_out_out) ,
    .frame_vaild (frame_vaild_out) ,
    .line_vaild  (line_vaild_out )  
);
//parameter define
parameter   FOT        =   3'b001 ,   //帧空闲状态
            WR_EN      =   3'b010 ,   //行使能状态
            ROT        =   3'b100 ;   //行空闲状态

DAQ_sync DAQ_sync_inst
(
    .sys_clk     ( sys_clk   ),   //系统时钟，频率50MHz
    .sys_rst_n   ( data_gen_rst ),   //复位信号,低电平有效
    .data_in0    ( data_in0  ),
    .data_in1    ( data_in1  ),
    .data_in2    ( data_in2  ),
    .data_in3    ( data_in3  ),
    .data_in4    ( data_in4  ),
    .data_in5    ( data_in5  ),
    .data_in6    ( data_in6  ),
    .data_in7    ( data_in7  ),
 
    .clk_out     ( clk_out   ),  //像素同步信号
    .frame_vaild (frame_vaild),  //帧同步信号
    .line_vaild  (line_vaild ),  //行同步信号

    .state       (  state    ),


    .data_in     (  data_in  ),
    .daq_clk     (  daq_clk  )
);

SPI_transfer SPI_transfer_inst
(
    .sck         (  sck      ),   //主机输入的串行时钟
    .sys_rst_n   ( sys_rst_n ),   //复位信号,低电平有效
    .data_in     (  data_out ),
    .valid       (  valid    ),
    .cs_n        (  cs_n     ),
    .miso        (  miso     ),   //主输出从输入数据
    .cnt_bit     (  cnt_bit  )    //比特计数器

);

ring_fifo#(
    .data_width    ( data_width  ),   //数据宽度
    .data_depth    ( data_depth  ),   //FIFO深度
    .addr_width    ( addr_width  ),   //地址宽度
    .package_size  (package_size )    //总包长，正常应该是38912
)ring_fifo_inst
(
    .sys_clk       (   sys_clk   ),
    .rst_n         (  sys_rst_n  ),       //异步复位
    .wr_clk        (   daq_clk   ),       //数据写时钟
    .wr_en         (    wr_en    ),       //输入使能
    .din           (   data_in   ),       //输入数据
    .rd_clk        (    rd_clk   ),       //数据读时钟
    .rd_en         (    rd_en    ),       //输出使能
    .intr_out      (   intr_out  ),
    
    .valid         (    valid    ),       //数据有效标志(在FIFO中数据发完后会重复发送最后一个bit，这时只需要加valid判断即可)
    .dout          (   data_out  ),       //输出数据
    .package_ready (package_ready),       //FIFO中存入一包数据标志
    .rd_out        (    rd_out   ),       //读空标志信号

    .empty         (   empty     ),
    .empty1        (   empty1    ),
    .empty2        (   empty2    ),
    .full1         (   full1     ),
    .full2         (   full2     ),
    .wr_en1        (   wr_en1    ),
    .wr_en2        (   wr_en2    ),
    .rd_en1        (   rd_en1    ),
    .rd_en2        (   rd_en2    ),
    .rd_sel        (   rd_sel    ),
    .dout1         (   dout1     ),
    .dout2         (   dout2     ),
    .valid1        (   valid1    ),
    .valid2        (   valid2    ),
    .emp_sel       (  emp_sel    ),
    .wr_addr1      (  wr_addr1   ),
    .rd_addr1      (  rd_addr1   ),
    .wr_addr2      (  wr_addr2   ),
    .rd_addr2      (  rd_addr2   ),
    .ram_wr_sel    ( ram_wr_sel  ),
    .ram1_rd_sel   ( ram1_rd_sel ),
    .ram2_rd_sel   ( ram2_rd_sel )
);

//数据采集状态机
state_ctrl#(.FOT (FOT), .WR_EN (WR_EN), .ROT (ROT))
state_ctrl_inst(
    .clk         (  sys_clk  ),
    .rst_n       ( sys_rst_n ),
    .line_vaild  (line_vaild ),
    .frame_vaild (frame_vaild),

    .state       (  state    )
);

//FIFO读时钟产生，8位数据读出一次
sck2rd_clk sck2rd_clk_inst(.sck(sck), .sys_rst_n(sys_rst_n), .rd_clk(rd_clk));

//产生写使能信号wr_en
assign wr_en = line_vaild;

//FIFO读信号是ESP32传来的片选信号取反
assign rd_en = ~cs_n;   

assign intr_out = package_ready;

//对package_ready进行5个daq_clk的延迟得到ESP32中断触发信号intr_out
//delayn#(.n(5)) delayn_inst(.clk(daq_clk), .rst_n(sys_rst_n), .in(package_ready), .out(intr_out));

//状态指示灯
LEDctrl LEDctrl_status(.clk(sys_clk), .rst(sys_rst_n), .signal(package_ready), .led_ctrl(status_led));

//CMOS退出低功耗开始曝光，曝光LED
LEDctrl LEDctrl_monitor(.clk(sys_clk), .rst(sys_rst_n), .signal(monitor), .led_ctrl(monitor_led));

endmodule