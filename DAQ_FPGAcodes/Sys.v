`timescale  1ns/1ns

module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 600,
    parameter   addr_width = 12,
    parameter   row_depth  = 304,
    parameter   colume_width = 304,
    parameter   row_num = 8,
    parameter   package_size = 38192
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

    //input   wire            start_intr   , //ESP32传来的启动信号
    
    output  wire    [7:0]   data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,   //片选信号
    input   wire            sck         ,   //串行时钟
    output  reg             cs_line_set      ,   //输出的数据同步使能信号
    output  wire            miso        ,   //主输出从输入数据
    output  wire    [2:0]   cnt_bit     ,    //比特计数器
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  wire            start_trans ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    //output  reg            pro_linevalid1,
    //output  reg            pro_linevalid2,
    output   wire  [addr_width-1:0]  wr_addr      ,
    output   wire  [addr_width-1:0]  rd_addr      ,
    //output   reg   [9:0]   send_cnt,
    //output   reg      cs_line_set_pre,
    //output   reg   [9:0] rec_cnt_index,
    //output   reg   [9:0] rec_comp_index,
    //output   reg   [9:0] rec_cnt_ram_revel,
    //output   reg   [9:0] rec_send_comp_revel,
    //output   wire  [15:0]   sent_cnt,
    //output   reg   [3:0]   cs_line_cnt,
    //output   reg          cs_multi_line_intr,
    //output   reg         clk_us,
    //output   reg [5:0]   clk_us_cnt,  
    //output   wire   [3:0]  duty_cnt,
    //output   wire     state_flag,
    //output   wire     multi_line_flag,
    //output   reg      cs_out,
    //output   reg     [7:0]  pre_delay_cnt,  //用来产生延时
    //output   reg            pre_delay_flag,
    //output   reg     [7:0]  pos_delay_cnt,
    //output   reg            pos_delay_flag,
    output   reg            intr_out

);

//parameter define
parameter   FOT           =   3'b001 ,   //帧空闲状态
            WR_EN         =   3'b010 ,   //行使能状态
            ROT           =   3'b100 ;   //行空闲状态

reg     [7:0]  pre_delay_cnt;  //用来产生延时
reg            pre_delay_flag;
reg     [7:0]  pos_delay_cnt;
reg            pos_delay_flag;
reg     [7:0]  delay_cnt;
reg            delay_flag;
wire            package_ready;  //FIFO传来的标志数据包准备好的信号
reg            finish_trans;    //传给FIFO的标志一包数据传输结束的信号
reg            start_intr;
reg     [9:0]  package_cnt;
reg     [9:0]  finish_cnt;
reg     cs_pos_edge;
reg     cs_pre_edge;
reg     cs_n_posedge;
reg     cs_n_negedge;
wire    cs_p;
reg     pos_delay_start;
reg     first_pre_delay_start;
reg     pos_start_intr;
reg     start_intr_posedge;

//assign multi_line_flag = state_flag | cs_multi_line_intr;

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
    .daq_clk     (daq_clk    ),
    .rec_cnt     (rec_cnt    )
);

SPI_transfer SPI_transfer_inst
(
    .sck         (sck        ),   //主机输入的串行时钟
    .sys_rst_n   (sys_rst_n  ),   //复位信号,低电平有效

    .data_in     (data_out   ),
    //.start_trans (start_trans),
    .valid       (valid      ),
    //.cs_set      (cs_line_set_pre ),
    .cs_n        (cs_n       ),

    .miso        (miso       ),   //主输出从输入数据
    .cnt_bit     (cnt_bit    ),   //比特计数器
    .sent_cnt    (sent_cnt   )
    //.duty_cnt    (duty_cnt   ),
    //.state_flag  (state_flag )
);
//reg delaied_rd_clk;
//这个fifo现有的问题是启动会延迟一段时间，且会丢失起始数据
fifo_async#(
    .data_width (8),
    .data_depth (600),
    .addr_width (12)
)fifo_async_inst
(
    .rst_n  (sys_rst_n ),
    .wr_clk (daq_clk   ),
    .wr_en  (line_vaild),
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (start_trans),  //start_trans信号应该是ESP32传来的CS信号取反
    .valid  (valid     ),
    .dout   (data_out  ),
    .spi_sck(sck       ),
    .cs_n   (cs_n      ),
    .finish_trans (finish_trans),
    .empty  (rd_empty  ),
    .full   (wr_full   ),
    .package_ready (package_ready ),
    .wr_addr       (wr_addr       ),
    .rd_addr       (rd_addr       )
    );

assign start_trans = ~ cs_n;    //开始传输信号是CS信号取反
assign cs_p = ~ cs_n;   

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

//reg     start_intr;     //这个信号是自己配的，目的是启动SPI传输（这并不会控制DAQ模块的工作，但也会影响FIFO的读取）
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_intr <= 1'b0;
    else if(rd_empty != 1'b1)
        start_intr <= 1'b1;         //CS信号应该是在start_intr和延时100个clk的周期之后
    else 
        start_intr <= start_intr;   
    //当DAQ模块开始采集数据后开始中断使能信号输出，因为ESP32端还需要40~60us的时间来初始化SPI总线，因此这个时长不会影响正常传输逻辑
end

/*配置中断使能信号（没有行检测机制）*/
/*----------------------------------CS信号边沿检测---------------------------------------*/  
//这个边沿检测现存的问题是在系统初始化后会立即产生一个边沿检测脉冲，因此换成检测cs取反后的信号了
//cs信号打拍得到cs_pos_edge
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_pos_edge <= 1'b0;
    else
        cs_pos_edge <= cs_p;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_pre_edge <= 1'b0;
    else
        cs_pre_edge <= cs_n;
end

//检测cs上升沿
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_n_posedge <= 1'b0;
    else if((cs_pos_edge == 1'b1) && (cs_p == 1'b0))  //检测上升沿
        cs_n_posedge <= 1'b1;
    else
        cs_n_posedge <= 1'b0;
end

//检测cs下降沿
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_n_negedge <= 1'b0;
    else if((cs_pre_edge == 1'b1) && (cs_n == 1'b0))  //检测下降沿
        cs_n_negedge <= 1'b1;
    else
        cs_n_negedge <= 1'b0;
end

//检测start_intr的上升沿
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pos_start_intr <= 1'b0;
    else
        pos_start_intr <= start_intr;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_intr_posedge <= 1'b0;
    else if((pos_start_intr == 1'b0) && (start_intr == 1'b1))  //检测上升沿
        start_intr_posedge <= 1'b1;
    else
        start_intr_posedge <= 1'b0;
end

/*------------------------------产生pre_delay_flag信号--------------------------------*/
//产生一个pre_delay使能信号，这是为了在第一个周期传输时置起pre_delay_flag的，因此在第一个cs下降沿到来时被拉低
always @(posedge sys_clk or negedge sys_rst_n) begin    
    if(sys_rst_n == 1'b0)
        first_pre_delay_start <= 1'b0;
    else if((start_intr ==1'b1) && (cs_n == 1'b1))  //当一包传输结束后,这时CS信号已经产生，可以通过CS信号进行控制
        first_pre_delay_start <= start_intr;         //为保证每次都准确在cs_out前插入时延，在cs_out为1时清零flag和计数器
    else if(cs_n == 1'b0)
        first_pre_delay_start <= 1'b0;
    else
        first_pre_delay_start <= first_pre_delay_start;
end

//首先是数据传输前的延时
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pre_delay_cnt <= 1'b0;
    //else if((cs_n == 1'b1) && (start_intr == 1'b0))
    else if(cs_n_posedge == 1'b1)
        pre_delay_cnt <= 1'b0;
    else if((pre_delay_flag == 1'b0) && (pos_delay_flag == 1'b1) && (package_cnt != finish_cnt))// && (package_ready == 1'b1) //由于CS信号是根据pre_delay_flag产生的，因此这里不能用CS信号做标志
        pre_delay_cnt <= pre_delay_cnt + 1'b1;
    //else if(first_pre_delay_start == 1'b1)
    //    pre_delay_cnt <=  pre_delay_cnt;    //计数到最大值后保持，直到cs_n拉高后清零
end

//这个信号何时拉起何时放下不需要配合CS考虑，因为CS信号是在delay_flag拉起后产生的
always @(posedge sys_clk or negedge sys_rst_n) begin    
    if(sys_rst_n == 1'b0)
        pre_delay_flag <= 1'b0;
    else if(cs_n_posedge ==1'b1)  //当一包传输结束后,这时CS信号已经产生，可以通过CS信号进行控制
        pre_delay_flag <= 1'b0;         //为保证每次都准确在cs_out前插入时延，在cs_out为1时清零flag和计数器
    else if(pre_delay_cnt == 8'd100)
        pre_delay_flag <= 1'b1;
    //else if(first_pre_delay_start == 1'b1)
    //    pre_delay_flag <= 1'b1;
    else if(start_intr_posedge == 1'b1)
        pre_delay_flag <= 1'b1;
    else
        pre_delay_flag <= pre_delay_flag;
end

/*-----------------------------产生pos_delay_flag信号----------------------------------*/
//产生包后延时开始信号
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pos_delay_start <= 1'b0;
    else if(cs_n_posedge == 1'b1)
        pos_delay_start <= 1'b1;
    else if(cs_n_negedge == 1'b1)
        pos_delay_start <= 1'b0;
    else
        pos_delay_start <= pos_delay_start;
end

//下面配置传输结束后的延时
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pos_delay_cnt <= 1'b0;
    //else if(cs_n == 1'b1)
    else if(pos_delay_start == 1'b1)
        pos_delay_cnt <= pos_delay_cnt + 1'b1;
    //else if(cs_n == 1'b0)   //这里CS信号已经产生了，可以根据CS信号进行配置
    else if(pos_delay_start == 1'b0)
        pos_delay_cnt <= 1'b0;
    else if(pos_delay_cnt == 8'd100)
        pos_delay_cnt <=  pos_delay_cnt;    //计数到最大值后保持，直到pos_delay_start拉低后清零
end

//这个信号何时拉起何时放下不需要配合CS考虑，因为CS信号是在delay_flag拉起后产生的
always @(posedge sys_clk or negedge sys_rst_n) begin    
    if(sys_rst_n == 1'b0)
        pos_delay_flag <= 1'b0;
    //else if(cs_n == 1'b0)  //当一包传输结束后,这时CS信号已经产生，可以通过CS信号进行控制
    else if(pos_delay_start == 1'b0)
        pos_delay_flag <= 1'b0;         //为保证每次都准确在cs_out前插入时延，在cs_out为1时清零flag和计数器
    else if((pos_delay_cnt == 8'd100) && (pos_delay_start == 1'b1))
        pos_delay_flag <= 1'b1;
    else
        pos_delay_flag <= pos_delay_flag;
end

//产生中断信号
always @(posedge sys_clk or negedge sys_rst_n) begin    //根据pre_delay_flag和pos_delay_flag的时序
    if(sys_rst_n == 1'b0)
        intr_out <= 1'b0;
    else if(pre_delay_flag == 1'b1)  
        intr_out <= 1'b1;        
    else if(pos_delay_flag == 1'b1)
        intr_out <= 1'b0;
    else
        intr_out <= intr_out;
end

//一包传输结束标志信号
always @(posedge sys_clk or negedge sys_rst_n) begin    //根据pre_delay_flag和pos_delay_flag的时序
    if(sys_rst_n == 1'b0)
        finish_trans <= 1'b0;     
    //else if(pos_delay_flag == 1'b1)
    else if(cs_n_posedge == 1'b1)       //这样写就是跟着cs信号走了，但是没有影响
        finish_trans <= 1'b1;       //一包数据传输结束标志信号
    else 
        finish_trans <= 1'b0;
end

//package计数信号，标志当前FIFO中有多少个FIFO等待发送（实际上最多一个）
always @(posedge sys_clk or negedge sys_rst_n) begin   
    if(sys_rst_n == 1'b0)
        package_cnt <= 1'b0;     
    else if(package_ready == 1'b1)
        package_cnt <= package_cnt + 1'b1;       //每当package_ready信号传来（FIFO中新增一包数据）就给计数器加一
    else 
        package_cnt <= package_cnt;
end

//finished package计数信号，标志当前已经有多少个package已经被发送了
always @(posedge sys_clk or negedge sys_rst_n) begin  
    if(sys_rst_n == 1'b0)
        finish_cnt <= 1'b0;     
    else if(finish_trans == 1'b1)
        finish_cnt <= finish_cnt + 1'b1;       //每当finish_trans信号传来，表示一包数据已经发送完，这是给计数器加一
    else 
        finish_cnt <= finish_cnt;
end

assign start_trans = ~ cs_n;


endmodule