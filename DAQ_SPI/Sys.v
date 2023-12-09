`timescale  1ns/1ns

module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 300,
    parameter   addr_width = 14,
    parameter   package_size = 300 ,
    parameter   multiline_num = 8
)
(
    input   wire            sys_clk     ,   //系统时钟，频率50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
/*    input   wire            data_in0    ,
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
*/
    //input   wire            start_intr   , //ESP32传来的启动信号
    
    output  wire    [7:0]   data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,   //片选信号
    input   wire            sck         ,   //串行时钟
    output  wire            miso        ,   //主输出从输入数据
    output  wire    [2:0]   cnt_bit     ,   //比特计数器
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    output  wire            package_ready,
    output  wire            clk_out     ,
    output  wire            wr_en       ,
    output  wire            rd_en       ,

    output  wire            intr_out    

);

//parameter define
parameter   FOT           =   3'b001 ,   //帧空闲状态
            WR_EN         =   3'b010 ,   //行使能状态
            ROT           =   3'b100 ;   //行空闲状态

wire            data_in0    ;
wire            data_in1    ;
wire            data_in2    ;
wire            data_in3    ;
wire            data_in4    ;
wire            data_in5    ;
wire            data_in6    ;
wire            data_in7    ;
//wire            clk_out     ;
wire            frame_vaild ;
wire            line_vaild  ;

DATA_GEN#(
    .CNT20_MAX  ( 4  ),
    .CNT10_MAX  ( 9  ),
    .CNT5_MAX   ( 19 ),
    .LINE_MAX   (100 ),
    .FRAME_MAX  (2000)
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

DAQ_sync DAQ_sync_inst
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

    .clk_out     (clk_out    ),  //像素同步信号
    .frame_vaild (frame_vaild),  //帧同步信号
    .line_vaild  (line_vaild ),  //行同步信号

    .state       (state      ),


    .data_in     (data_in    ),
    .daq_clk     (daq_clk    )
);

SPI_transfer SPI_transfer_inst
(
    .sck         (sck        ),   //主机输入的串行时钟
    .sys_rst_n   (sys_rst_n  ),   //复位信号,低电平有效
    .data_in     (data_out   ),
    .valid       (valid      ),
    .cs_n        (cs_n       ),
    .miso        (miso       ),   //主输出从输入数据
    .cnt_bit     (cnt_bit    )    //比特计数器

);

ring_fifo#(
    .data_width    ( data_width  ),   //数据宽度
    .data_depth    ( data_depth  ),   //FIFO深度
    .addr_width    ( addr_width  ),   //地址宽度
    .package_size  (package_size )    //总包长，正常应该是38912
)ring_fifo_inst
(
    .rst_n         (  sys_rst_n  ),       //异步复位
    .wr_clk        (   daq_clk   ),       //数据写时钟
    .wr_en         (    wr_en    ),       //输入使能
    .din           (   data_in   ),       //输入数据
    .rd_clk        (    rd_clk   ),       //数据读时钟
    .rd_en         (    rd_en    ),       //输出使能
    
    .valid         (    valid    ),       //数据有效标志(在FIFO中数据发完后会重复发送最后一个bit，这时只需要加valid判断即可)
    .dout          (   data_out  ),       //输出数据
    .package_ready (package_ready),       //FIFO中存入一包数据标志
    .rd_out        (    rd_out   )        //读空标志信号
);

//state:两段式状态机
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        state   <=  FOT;    //frame_valid不使能时state处于FOT状态
    else
    case(state)
        FOT:   
                if((frame_vaild == 1'b1) && (line_vaild == 1'b1))  
                    state <= WR_EN;   
                else if((frame_vaild == 1'b1) && (line_vaild == 1'b0))  
                    state <= ROT; 
                else
                    state <= FOT;  

        ROT:    if(line_vaild == 1'b1)
                    state <= WR_EN; 
                else if(frame_vaild == 1'b0)
                    state <= FOT;       
                else
                    state <= ROT;   //ROT的default状态
                    
        WR_EN:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_valid使能但line_valid失能时进入ROT行空闲状态
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_valid失能时直接回到FOT状态
                else
                    state <= WR_EN;    //保持读取状态
                    
        default:    state   <=  FOT;
    endcase
end

//sck_cnt的作用是标记当前已发送多少数据，为了产生rd_clk时钟
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  3'd0;
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

//产生写使能信号wr_en
assign wr_en = line_vaild;

//对package_ready进行三个daq_clk的延迟得到ESP32中断触发信号intr_out
wire   intr_out_pre;
assign intr_out_pre = package_ready;

delayn#(.n(3)) delayn_inst(.clk(daq_clk), .rst_n(rst_n), .in(intr_out_pre), .out(intr_out));

assign rd_en = ~cs_n;   //FIFO读信号是ESP32传来的片选信号取反

endmodule