module ring_fifo#(
    parameter   data_width = 8 ,     //数据宽度
    parameter   data_depth = 4864,    //FIFO深度
    parameter   addr_width = 14,    //地址宽度
    parameter   package_size = 4864   //总包长，正常应该是38912
)
(
    input   wire                    sys_clk,
    input   wire                    rst_n  ,       //异步复位
    input   wire                    wr_clk ,       //数据写时钟
    input   wire                    wr_en  ,       //输入使能
    input   wire  [data_width-1:0]  din    ,       //输入数据
    input   wire                    rd_clk ,       //数据读时钟
    input   wire                    rd_en  ,       //输出使能
    input   wire                    intr_out,

    output   wire                   valid  ,       //数据有效标志(在FIFO中数据发完后会重复发送最后一个bit，这时只需要加valid判断即可)
    output   wire [data_width-1:0]  dout   ,       //输出数据
    output   wire                   package_ready, //FIFO中存入一包数据标志
    output   wire                   rd_out        , //读空标志信号

    output   wire                   empty      ,
    output   wire                   empty1     ,
    output   wire                   empty2     ,
    output   wire                   full1      ,
    output   wire                   full2      ,
    output   wire                   wr_en1     ,
    output   wire                   wr_en2     ,
    output   wire                   rd_en1     ,
    output   wire                   rd_en2     ,
    output   reg                    rd_sel     ,
    output   wire [data_width-1:0]  dout1      ,
    output   wire [data_width-1:0]  dout2      ,  
    output   wire                   valid1     ,
    output   wire                   valid2     ,
    output   reg                    emp_sel    ,
    output   wire [addr_width-1:0]  wr_addr1   ,
    output   wire [addr_width-1:0]  rd_addr1   ,
    output   wire [addr_width-1:0]  wr_addr2   ,
    output   wire [addr_width-1:0]  rd_addr2   ,
    output   reg                    ram_wr_sel ,
    output   reg                    ram1_rd_sel,
    output   reg                    ram2_rd_sel

);
/*------------检测rd_en信号边沿------------*/
reg     rd_en_pre;
reg     rd_en_posedge;
always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        rd_en_pre <= 1'b0;
    else
        rd_en_pre <= rd_en;
end

always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        rd_en_posedge <= 1'b0;
    else if((rd_en_pre == 1'b0) && (rd_en == 1'b1))  //检测上升沿
        rd_en_posedge <= 1'b1;
    else
        rd_en_posedge <= 1'b0;
end

/*------------检测wr_en信号边沿------------*/
reg     wr_en_pre;
reg     wr_en_posedge;
always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        wr_en_pre <= 1'b0;
    else
        wr_en_pre <= rd_en;
end

always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        wr_en_posedge <= 1'b0;
    else if((wr_en_pre == 1'b0) && (wr_en == 1'b1))  //检测上升沿
        wr_en_posedge <= 1'b1;
    else
        wr_en_posedge <= 1'b0;
end

/*------------实现两组FIFO交替写入------------*/
/*在写时钟wr_clk下交替写入两个FIFO*/
//两个RAM的选择标志信号
always@(posedge wr_clk or negedge rst_n)    //这部分的目的是保证连续写入一个未写满的FIFO
    if(!rst_n)          //初始化
        ram_wr_sel <= 1'b0;
    else if(full1)   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        ram_wr_sel <= 1'b1;    
    else if(full2)   //FIFO2写满后使能FIFO1写入，FIFO2开始读出
        ram_wr_sel <= 1'b0;
    else 
        ram_wr_sel <= ram_wr_sel;

assign wr_en1 = (!ram_wr_sel) && (wr_en);
assign wr_en2 = (ram_wr_sel) && (wr_en);

/*在读时钟rd_clk下交替读取两个FIFO*/
//由于读时钟频率远远高于写时钟，所以数据不会出现读不完的情况
//数据读出是根据package_ready信号来标志的，package_ready置起就会触发ESP32中断，产生CS信号
always@(posedge rd_clk or negedge rst_n)    //这部分的目的是保证连续读取一个未读完的FIFO
    if(!rst_n) begin          //初始化
        ram1_rd_sel <= 1'b0;
        ram2_rd_sel <= 1'b0;
    end
    else if(full1) begin   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        ram1_rd_sel <= 1'b1; 
        ram2_rd_sel <= 1'b0; 
    end   
    else if(full2) begin  //FIFO2写满后使能FIFO1写入，FIFO2开始读出
        ram1_rd_sel <= 1'b0;
        ram2_rd_sel <= 1'b1;
    end
    else begin
        ram1_rd_sel <= ram1_rd_sel;
        ram2_rd_sel <= ram2_rd_sel;
    end

assign rd_en1 = (ram1_rd_sel) && (rd_en);
assign rd_en2 = (ram2_rd_sel) && (rd_en);

/*指示输出信号dout和valid由哪个FIFO传来*/
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n)         
        rd_sel <= 1'b0;
    else if(full1 == 1'b1)  
        rd_sel <= 1'b0;   //表明输出信号是FIFO1传来的    
    else if(full2 == 1'b1)   
        rd_sel <= 1'b1;   //表明输出信号是FIFO2传来的
    else                  
        rd_sel <= rd_sel;

/*配置输出信号empty*/
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n)       //初始化
        emp_sel <= 1'b0;
    else if(full1 == 1'b1)   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        emp_sel <= 1'b0; 
    else if(full2 == 1'b1)   //FIFO2写满后使能FIFO1写入，FIFO2开始读出
        emp_sel <= 1'b1;
    else   //在数据写入和读取过程中保持使能信号
        emp_sel <= emp_sel;

wire   rd_out1 ;
wire   rd_out2 ;

assign dout = (rd_sel) ? dout2 : dout1;
assign valid = (rd_sel) ? valid2 : valid1;
assign empty = (emp_sel) ? empty1 : empty2; 
assign rd_out = (rd_sel) ? rd_out2 : rd_out1;

/*生成package_ready信号*/
assign package_ready = ((full1 == 1'b1) || (full2 == 1'b1));
/*always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n) 
        package_ready <= 1'b0;
    else if((full1 == 1'b1) || (full2 == 1'b1))
        package_ready <= 1'b1;
    else 
        package_ready <= 1'b0; //该逻辑保证package_ready信号保持一个wr_clk周期
*/
/*下面的两个模块中，除了使能信号外全都接到顶层模块信号中*/
async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //正常应该是38912
)async_ram_inst1
(
    .sys_clk      (  sys_clk  ),
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en1   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en1   ),
    .intr_out     ( intr_out  ),

    .valid        (  valid1   ),
    .dout         (  dout1    ),
    .empty        (  empty1   ),
    .full         (  full1    ),
    .wr_addr      ( wr_addr1  ),
    .rd_addr      ( rd_addr1  ),
    .rd_out       ( rd_out1   ) 
);


async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //正常应该是38912
)async_ram_inst2
(
    .sys_clk      (  sys_clk  ),
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en2   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en2   ),
    .intr_out     ( intr_out  ),

    .valid        (  valid2   ),
    .dout         (  dout2    ),
    .empty        (  empty2   ),
    .full         (  full2    ),
    .wr_addr      ( wr_addr2  ),
    .rd_addr      ( rd_addr2  ),
    .rd_out       ( rd_out2   )   
);

endmodule