`timescale  1ns/1ns

module  spi_slave
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

    output  reg             start_sig   ,  //数据起始信号
    
    output  wire    [7:0]   data_out    ,
    output  reg             rd_req      ,
    output  reg             wr_req      ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  reg    [7:0]    data_in     ,
    input   wire            cs_n        ,   //片选信号
    input   wire            sck         ,   //串行时钟
    output  reg             mosi        ,   //主输出从输入数据
    output  reg     [2:0]   cnt_bit     ,    //比特计数器
    output  reg     [3:0]   state       ,
    output  reg             daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  reg             rd_clk

);

//parameter define
parameter   FOT           =   4'b0001 ,   //帧空闲状态
            WR_EN_FRAME   =   4'b0010 ,   //帧使能状态
            WR_EN_LINE    =   4'b0001 ,   //行使能状态
            ROT           =   4'b0010 ;   //行空闲状态

//把pclk在sys_clk打拍以保证可以稳定采样(限制条件是F_sys_clk > F_pclk)
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        daq_clk <= 1'b0;
    else
        daq_clk <= clk_out;
end

//sck_cnt的作用是标记当前已发送多少数据，为了产生rd_clk时钟
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  3'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

//rd_sck是sck八分频后的时钟，指示fifo的读出周期
always@(posedge sck or  negedge sys_rst_n)  //在sck上升沿产生rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 3'd7)
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//以pclk打拍后的rd_sck为时钟采样输入data0~7信号
always @(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        data_in <= 0;
    else if(state == WR_EN) begin
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
    .wr_en  (wr_req    ),
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (!hsync    ),  //这改了
    .valid  (valid     ),
    .dout   (data_out  ),
    .empty  (rd_empty  ),
    .full   (wr_full   )
    );


//cnt_bit:高低位对调，控制mosi输出
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <=  3'd0;
    else
        cnt_bit <=  cnt_bit + 1'b1;


//state:两段式状态机第一段，状态跳转
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  FOT;    //frame_valid不使能时state处于FOT状态
    else
    case(state)
        FOT:   
                if(frame_vaild == 1'b1)  
                    state <= WR_EN_FRAME;   //frame_valid使能后state进入WR_EN_FRAME状态等待line_valid使能
                else
                    state <= FOT;   //frame_valid不使能时state处于FOT状态

        WR_EN_FRAME:  
                if(line_vaild == 1'b1)  
                    state <= WR_EN_LINE;   //frame_valid使能且line_valid使能时进入行读取状态，开始逐行读取数据
                else if(frame_vaild == 1'b0)
                    state <= FOT;     //在WR_EN_FRAME状态当frame_valid失能后跳转到FOT状态
                else
                    state <= ROT;   //frame_valid使能但line_valid未使能时处于ROT状态等待line_valid使能

        ROT:    if(line_vaild == 1'b1)
                    state <= WR_EN_LINE; //frame_valid使能且line_valid使能时进入行读取状态，开始逐行读取数据
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_valid失能后跳转到FOT状态，和WR_EN_LINE(frame_vaild == 1'b0)进入
                                        //FOT不冲突，因为进入WR_EN_LINE的前提是line_vaild使能，但line_vaild失能也能进入ROT
                else
                    state <= ROT;   //ROT的default状态
                    
        WR_EN_LINE:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_valid使能但line_valid失能时进入ROT行空闲状态
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_valid失能时直接回到FOT状态
                else
                    state <= WR_EN_LINE;    //保持读取状态
                    
        default:    state   <=  FOT;
    endcase


//初始化FIFO读写使能信号，rd_req信号是状态变为IDLE的后一拍
always@(posedge sys_clk or  negedge sys_rst_n)
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
    else if(state == WR_EN && (cnt_bit == 3'b000))
        mosi <= data_out[7-cnt_bit];    //写使能指令
    else if((state == WR_EN) && (rd_empty == 1'b1)) 
        mosi <= 8'b1111_1111;   //发送一个全1数据包表示摄像头传输结束
    else    if(state == IDLE)
        mosi    <=  1'b0;



endmodule



`timescale  1ns/1ns
/*调试进度：目前rec_cnt_index调试无误，rec_camp_index还有错，主要是sned_cnt错误跳变*/
module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 600,
    parameter   addr_width = 12,
    parameter   row_depth  = 304,
    parameter   colume_width = 304,
    parameter   row_num = 8
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
    
    output  wire    [7:0]   data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,   //片选信号
    input   wire            sck         ,   //串行时钟
    output  reg             cs_set      ,   //输出的数据同步使能信号
    output  wire            miso        ,   //主输出从输入数据
    output  wire    [2:0]   cnt_bit     ,    //比特计数器
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  reg             start_trans ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    output  reg            pro_linevalid1,
    output  reg            pro_linevalid2,
    output   wire  [addr_width:0]    wr_addr_ptr  ,//地
    output   wire  [addr_width:0]    rd_addr_ptr  ,
    output   wire  [addr_width-1:0]  wr_addr      ,//RAM 地
    output   wire  [addr_width-1:0]  rd_addr      ,
    output   wire  [addr_width:0]    wr_addr_gray ,//地  
    output   wire  [addr_width:0]    rd_addr_gray,
    output   wire  [9:0]   rec_cnt,
    output   reg   [9:0]   send_cnt,
    output   reg      cs_set_pre,
    output   reg   [9:0] rec_cnt_index,
    output   reg   [9:0] rec_comp_index,
    output   reg   [9:0] rec_cnt_ram_revel,
    output   reg   [9:0] rec_send_comp_revel,
    output   wire  [15:0]   sent_cnt,
    output   reg   [3:0]   cs_cnt,
    output   reg          cs_intr,
    output   reg         clk_us,
    output   reg [5:0]   clk_us_cnt,  
    output   reg     cs_set1,
    output   wire   [3:0]  duty_cnt,
    output   wire     state_flag
);

//parameter define
parameter   FOT           =   3'b001 ,   //帧空闲状态
            WR_EN         =   3'b010 ,   //行使能状态
            ROT           =   3'b100 ;   //行空闲状态

wire  [addr_width:0]    wr_addr_gray_d1;
wire  [addr_width:0]    wr_addr_gray_d2;
wire  [addr_width:0]    rd_addr_gray_d1;
wire  [addr_width:0]    rd_addr_gray_d2;


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
    .cs_set      (cs_set_pre ),

    .miso        (miso       ),   //主输出从输入数据
    .cnt_bit     (cnt_bit    ),   //比特计数器
    .sent_cnt    (sent_cnt   ),
    .duty_cnt    (duty_cnt   ),
    .state_flag  (state_flag )
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
    .rd_en  (start_trans),  //注意时序问题
    .valid  (valid     ),
    .dout   (data_out  ),
    .spi_sck(sck       ),
    .empty  (rd_empty  ),
    .full   (wr_full   ),
    .wr_addr_ptr        (wr_addr_ptr    ),
    .rd_addr_ptr        (rd_addr_ptr    ),
    .wr_addr            (wr_addr        ),
    .rd_addr            (rd_addr        ),
    .wr_addr_gray       (wr_addr_gray   ),
    .wr_addr_gray_d1    (wr_addr_gray_d1),
    .wr_addr_gray_d2    (wr_addr_gray_d2),
    .rd_addr_gray       (rd_addr_gray   ),
    .rd_addr_gray_d1    (rd_addr_gray_d1),
    .rd_addr_gray_d2    (rd_addr_gray_d2)
    );

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

//配置cs信号
reg [row_depth-1:0] rec_cnt_ram [colume_width:0];
//reg [row_depth-1:0] rec_cnt_index;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt_index <= 1'b0;
    else if((pro_linevalid2 != pro_linevalid1) && (state == ROT))
        rec_cnt_index <= rec_cnt_index + 1'b1;
    else
        rec_cnt_index <= rec_cnt_index;
end

//assign rec_cnt_ram[rec_cnt_index] = rec_cnt;

always @(negedge pro_linevalid1 or negedge sys_rst_n) begin
    rec_cnt_ram[rec_cnt_index] = rec_cnt;
end

//reg [row_depth-1:0] rec_comp_index;

always @(*) begin
    rec_cnt_ram_revel <= rec_cnt_ram[rec_cnt_index]; 
    //在这仿真波形出现X态的原因是每次rec_cnt_index更新后，rec_cnt_ram[rec_cnt_index]的值是不确定的   
end

always @(posedge rd_clk or negedge sys_rst_n) begin
        rec_send_comp_revel <= rec_cnt_ram[rec_comp_index];
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_cnt <= 1'b1;  //给1的原因是send_cnt要落后于valid一个时钟周期，初始值为1时刚好匹配
        rec_comp_index <= 1'b0;
        //sent_cs_cnt <= 1'b0;
    end
    else if(send_cnt == rec_cnt_ram[rec_comp_index]) begin
        send_cnt <= 1'b0;
        rec_comp_index <= rec_comp_index + 1'b1;
        //sent_cs_cnt <= sent_cs_cnt + 1'b1;
    end
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index)) //后面的条件是保证当Valid信号为低后依然可以继续发完数据
        send_cnt <= send_cnt + 1'b1;
    else
        send_cnt <= 1'b0;
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) 
        rec_comp_index <= 1'b0;
    else if((send_cnt == rec_cnt_ram[rec_comp_index]) && ((valid == 1'b1) || (rec_cnt_index != rec_comp_index))) 
        rec_comp_index <= rec_comp_index + 1'b1;
    else
        rec_comp_index <= rec_comp_index;
end

/*
//设置一个计数器，当发送数据达到接收数据后结束发送
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        send_cs_cnt <= 1'b0;
    else
        send_cs_cnt <= rec_cnt_ram[rec_comp_index];
end*/

/*
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        rec_comp_index <= 1'b0;
    end
    else if(send_cnt == 1'b0) begin
        rec_comp_index <= rec_comp_index + 1'b1;
    end
    else
        rec_comp_index <= rec_comp_index;
end*/
/*
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set_pre <= 1'b1;
    else if(send_cnt == rec_cnt_ram[rec_comp_index])
        cs_set_pre <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_set_pre <= 1'b0;
    else
        cs_set_pre <= 1'b1;
end*/

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set_pre <= 1'b1;
    else if(send_cnt == rec_cnt_ram[rec_comp_index])
        cs_set_pre <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_set_pre <= 1'b0;
    else
        cs_set_pre <= 1'b1;
end

/*reg     cs_set_pre1;

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set_pre1 <= 1'b1;
    else
        cs_set_pre1 <= cs_set_pre;
end*/
/*
//把cs_set1同步到rd_clk的时钟下
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set1 <= 1'b1;
    else
        cs_set1 <= cs_set_pre;
end*/

always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set <= 1'b1;
    else
        cs_set <= cs_set_pre;
end

always @(negedge cs_set_pre or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_cnt <= 1'b0;
    else if(cs_cnt == 4'd8)
        cs_cnt <= 1'b0;
    else
        cs_cnt <= cs_cnt + 1'b1;
end

always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_intr <= 1'b1;
    else if(cs_cnt == 4'd0)
        cs_intr <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_intr <= 1'b0;
    else
        cs_intr <= cs_intr;
end

//产生1us的时钟信号
always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us_cnt <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us_cnt <= 1'b0;
    else
        clk_us_cnt <= clk_us_cnt + 1'b1;
end

always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us <= ~clk_us;
    else
        clk_us <= clk_us;
end


/*
//rd_sck是sck八分频后的时钟，指示fifo的读出周期
always@(posedge sck or negedge sys_rst_n)  //在sck上升沿产生rd_clk
    if(sys_rst_n == 1'b0) 
        delaied_rd_clk <=  1'b0;
    else 
        delaied_rd_clk <=  rd_clk;*/

/*
//state:两段式状态机第一段，状态跳转
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  FOT;    //frame_valid不使能时state处于FOT状态
    else
    case(state)
        FOT:   
                if(frame_vaild == 1'b1)  
                    state <= WR_EN_FRAME;   //frame_valid使能后state进入WR_EN_FRAME状态等待line_valid使能
                else
                    state <= FOT;   //frame_valid不使能时state处于FOT状态

        WR_EN_FRAME:  
                if(line_vaild == 1'b1)  
                    state <= WR_EN_LINE;   //frame_valid使能且line_valid使能时进入行读取状态，开始逐行读取数据
                else if(frame_vaild == 1'b0)
                    state <= FOT;     //在WR_EN_FRAME状态当frame_valid失能后跳转到FOT状态
                else
                    state <= ROT;   //frame_valid使能但line_valid未使能时处于ROT状态等待line_valid使能

        ROT:    if(line_vaild == 1'b1)
                    state <= WR_EN_LINE; //frame_valid使能且line_valid使能时进入行读取状态，开始逐行读取数据
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_valid失能后跳转到FOT状态，和WR_EN_LINE(frame_vaild == 1'b0)进入
                                        //FOT不冲突，因为进入WR_EN_LINE的前提是line_vaild使能，但line_vaild失能也能进入ROT
                else
                    state <= ROT;   //ROT的default状态
                    
        WR_EN_LINE:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_valid使能但line_valid失能时进入ROT行空闲状态
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_valid失能时直接回到FOT状态
                else
                    state <= WR_EN_LINE;    //保持读取状态
                    
        default:    state   <=  FOT;
    endcase*/

//state:两段式状态机第一段，状态跳转
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

//下面打两拍是为了配合state的时序，这样才能和state对齐,同时空出来的一段时间也可以给CS信号用来拉高标志一包传输结束
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid1 <= 1'b0;
    else
        pro_linevalid1 <= line_vaild;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid2 <= 1'b0;
    else
        pro_linevalid2 <= pro_linevalid1;
end

//根据state产生start_trans信号
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_trans <= 1'b0;
    //else if((state == WR_EN) && (cs_n == 1'b0))
    //    start_trans <= 1'b1;
    else if((pro_linevalid2 != line_vaild) && (state == ROT))
        start_trans <= 1'b1;
    else
        start_trans <= start_trans;
end

/*
//根据state产生start_trans信号,这个信号在第一个line_valid信号来的时候(开始有数据之后)就直接拉高开始传输
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_trans <= 1'b0;
    else if(line_vaild == 1'b1)
        start_trans <= 1'b1;
    else
        start_trans <= start_trans;
end*/
endmodule



    //output   reg     [7:0]  delay_cnt,
    //output   reg            delay_flag,
    //output   wire            package_ready,      //FIFO传来的标志数据包准备好的信号
    //output   reg            finish_trans,  //传给FIFO的标志一包数据传输结束的信号
    //output   reg            start_intr,
    //output   reg     [9:0]  package_cnt,
    //output   reg     [9:0]  finish_cnt,
    //output   reg     cs_pos_edge,
    //output   reg     cs_pre_edge,
    //output   reg     cs_n_posedge,
    //output   reg     cs_n_negedge,
    //output   wire    cs_p,
    //output   reg     pos_delay_start,
    //output   reg     first_pre_delay_start,
    //output   reg     pos_start_intr,
    //output   reg     start_intr_posedge


/*--------------------------------------------------------------------------------------------------*/
/*
//配置cs信号
//下面的处理有行检测机制，可以实现每行不同长度的传输
reg [row_depth-1:0] rec_cnt_ram [colume_width:0];
//reg [row_depth-1:0] rec_cnt_index;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt_index <= 1'b0;
    else if((pro_linevalid2 != pro_linevalid1) && (state == ROT))
        rec_cnt_index <= rec_cnt_index + 1'b1;
    else
        rec_cnt_index <= rec_cnt_index;
end

//assign rec_cnt_ram[rec_cnt_index] = rec_cnt;

always @(negedge pro_linevalid1 or negedge sys_rst_n) begin
    rec_cnt_ram[rec_cnt_index] = rec_cnt;
end

//reg [row_depth-1:0] rec_comp_index;

always @(*) begin
    rec_cnt_ram_revel <= rec_cnt_ram[rec_cnt_index]; 
    //在这仿真波形出现X态的原因是每次rec_cnt_index更新后，rec_cnt_ram[rec_cnt_index]的值是不确定的   
end

always @(posedge rd_clk or negedge sys_rst_n) begin
        rec_send_comp_revel <= rec_cnt_ram[rec_comp_index];
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_cnt <= 1'b1;  //给1的原因是send_cnt要落后于valid一个时钟周期，初始值为1时刚好匹配
        rec_comp_index <= 1'b0;
        //sent_cs_cnt <= 1'b0;
    end
    else if(send_cnt == rec_cnt_ram[rec_comp_index]) begin
        send_cnt <= 1'b0;
        rec_comp_index <= rec_comp_index + 1'b1;
        //sent_cs_cnt <= sent_cs_cnt + 1'b1;
    end
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index)) //后面的条件是保证当Valid信号为低后依然可以继续发完数据
        send_cnt <= send_cnt + 1'b1;
    else
        send_cnt <= 1'b0;
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) 
        rec_comp_index <= 1'b0;
    else if((send_cnt == rec_cnt_ram[rec_comp_index]) && ((valid == 1'b1) || (rec_cnt_index != rec_comp_index))) 
        rec_comp_index <= rec_comp_index + 1'b1;
    else
        rec_comp_index <= rec_comp_index;
end

//这是产生行传输标志信号的（比MISO时序差一个SCK周期）
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_line_set_pre <= 1'b1;
    else if(send_cnt == rec_cnt_ram[rec_comp_index])
        cs_line_set_pre <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_line_set_pre <= 1'b0;
    else
        cs_line_set_pre <= 1'b1;
end

//cs_line_set_pre打拍来配合MISO时序
always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_line_set <= 1'b1;
    else
        cs_line_set <= cs_line_set_pre;
end

//用来产生cs_multi_line_intr信号的计数器，8个cs_line_set周期作为一个包并产生一个cs_multi_line_intr信号
always @(negedge cs_line_set_pre or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_line_cnt <= 1'b0;
    else if(cs_line_cnt == 4'd8)
        cs_line_cnt <= 1'b0;
    else
        cs_line_cnt <= cs_line_cnt + 1'b1;
end

//这个信号标志着八位数据传输完成（比MISO信号慢一个rd_clk周期）
always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_multi_line_intr <= 1'b1;
    else if(cs_line_cnt == 4'd0)
        cs_multi_line_intr <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_multi_line_intr <= 1'b0;
    else
        cs_multi_line_intr <= cs_multi_line_intr;
end

//这个信号是cs_multi_line_intr在rd_clk下打一拍得到的，它是配合valid时序的八位数据传输标志信号
reg cs_out_pre;
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_out_pre <= 1'b1;
    else
        cs_out_pre <= cs_multi_line_intr;
end

//cs_out是multi_line_flag在sck下打一拍得到的
always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_out <= 1'b1;
    else
        cs_out <= cs_out_pre;
end

//在包头/尾插入固定时延
//reg     [5:0]   delay_cnt;
//在包头添加的延时通过改变计数器最大计数值改变
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        delay_cnt <= 1'b0;
    else if(delay_cnt == 8'd100)
        delay_cnt <= 1'b0;
    else 
        delay_cnt <= delay_cnt + 1'b1;
end

//reg     delay_flag;
always @(posedge sys_clk or negedge sys_rst_n) begin     //这个触发时钟只有在sck下才正常
    if(sys_rst_n == 1'b0)
        delay_flag <= 1'b0;
    else if(cs_out == 1'b1)
        delay_flag <= 1'b0;         //为保证每次都准确在cs_out前插入时延，在cs_out为1时清零flag和计数器
    else if(delay_cnt == 8'd100)
        delay_flag <= 1'b1;
    else
        delay_flag <= delay_flag;
end

//产生1us的时钟信号
always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us_cnt <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us_cnt <= 1'b0;
    else
        clk_us_cnt <= clk_us_cnt + 1'b1;
end

always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us <= ~clk_us;
    else
        clk_us <= clk_us;
end

//下面打两拍是为了配合state的时序，这样才能和state对齐,同时空出来的一段时间也可以给CS信号用来拉高标志一包传输结束
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid1 <= 1'b0;
    else
        pro_linevalid1 <= line_vaild;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid2 <= 1'b0;
    else
        pro_linevalid2 <= pro_linevalid1;
end

//根据state产生start_trans信号
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_trans <= 1'b0;
    //else if((state == WR_EN) && (cs_n == 1'b0))
    //    start_trans <= 1'b1;
    else if((pro_linevalid2 != line_vaild) && (state == ROT))
        start_trans <= 1'b1;
    else
        start_trans <= start_trans;
end

*/