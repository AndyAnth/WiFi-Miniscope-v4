module ring_fifo#(
    parameter   data_width = 8,
    parameter   data_depth = 60,
    parameter   addr_width = 14,
    parameter   package_size = 60  //正常应该是38912
)
(
    input   wire                    rst_n  ,
    input   wire                    wr_clk ,
    input   wire                    wr_en  ,
    input   wire  [data_width-1:0]  din    ,         
    input   wire                    rd_clk ,
    input   wire                    rd_en  ,

    output   wire                   valid  ,
    output   wire [data_width-1:0]  dout   ,
    output   reg                    package_ready, //指示待发送数据包已准备好
    output   wire                   empty  ,
    output   wire                   empty1 ,
    output   wire                   full1  ,
    output   wire                   empty2 ,
    output   wire                   full2  ,
    output   wire                   wr_en1 ,
    output   wire                   wr_en2 ,
    output   wire                   rd_en1 ,
    output   wire                   rd_en2 ,
    output   wire                   rd_out ,
    output   reg                    rd_sel ,
    output   wire [data_width-1:0]  dout1  ,
    output   wire [data_width-1:0]  dout2  ,  
    output   wire                   valid1 ,
    output   wire                   valid2 ,
    output   reg                    emp_sel,
    output   wire [addr_width-1:0]  wr_addr1,
    output   wire [addr_width-1:0]  rd_addr1,
    output   wire [addr_width-1:0]  wr_addr2,
    output   wire [addr_width-1:0]  rd_addr2,
    output   reg                    ram_wr_sel,
    output   reg                    ram1_rd_sel,
    output   reg                    ram2_rd_sel
);

//两个FIFO间选择的使能信号
//reg    wr_en1;
//reg    wr_en2;
//reg    rd_en1;
//reg    rd_en2;

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
//两个RAM的选择信号(写满了一个就写另一个，读这个)
always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n)          //初始化
        ram_wr_sel <= 1'b0;
    else if(full1)   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        ram_wr_sel <= 1'b1;    
    else if(full2)   //FIFO2写满后使能FIFO1写入，FIFO2开始读出
        ram_wr_sel <= 1'b0;
    else 
        ram_wr_sel <= ram_wr_sel;

assign wr_en1 = (~ram_wr_sel) && (wr_en);
assign wr_en2 = (ram_wr_sel) && (wr_en);

/*在读时钟rd_clk下交替读取两个FIFO*/
//由于读时钟频率远远高于写时钟，因此一个FIFO满了以后会立即被读取，而不会出现跳过一段数据的情况
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n) begin          //初始化
        ram1_rd_sel <= 1'b0;
        ram2_rd_sel <= 1'b0;
    end
    else if(full1 && rd_en) begin   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        ram1_rd_sel <= 1'b1; 
        ram2_rd_sel <= 1'b0; 
    end   
    else if(full2 && rd_en) begin  //FIFO2写满后使能FIFO1写入，FIFO2开始读出
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
always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n) 
        package_ready <= 1'b0;
    else if((full1 == 1'b1) || (full2 == 1'b1))
        package_ready <= 1'b1;
    else 
        package_ready <= 1'b0; //该逻辑保证package_ready信号保持一个wr_clk周期

/*下面的两个模块中，除了使能信号外全都接到顶层模块信号中*/
async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //正常应该是38912
)async_ram_inst1
(
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en1   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en1   ),

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
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en2   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en2   ),

    .valid        (  valid2   ),
    .dout         (  dout2    ),
    .empty        (  empty2   ),
    .full         (  full2    ),
    .wr_addr      ( wr_addr2  ),
    .rd_addr      ( rd_addr2  ),
    .rd_out       ( rd_out2   )   
);

endmodule