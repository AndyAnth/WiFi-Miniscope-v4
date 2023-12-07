module ring_fifo#(
    parameter   data_width = 8,
    parameter   data_depth = 30,
    parameter   addr_width = 14,
    parameter   package_size = 10  //正常应该是38912
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
    output   reg                    wr_en1 ,
    output   reg                    wr_en2 ,
    output   reg                    rd_en1 ,
    output   reg                    rd_en2 ,
    output   wire                   rd_out ,
    output   reg                    rd_sel ,
    output   wire [data_width-1:0]  dout1  ,
    output   wire [data_width-1:0]  dout2  ,  
    output   wire                   valid1 ,
    output   wire                   valid2 ,
    output   reg                    emp_sel,
    output   wire [addr_width-1:0]   wr_addr1,
    output   wire [addr_width-1:0]   rd_addr1,
    output   wire [addr_width-1:0]   wr_addr2,
    output   wire [addr_width-1:0]   rd_addr2
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

/*------------实现两组FIFO交替写入------------*/
/*在写时钟wr_clk下交替写入两个FIFO*/
always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n) begin         //初始化
        wr_en1 <= 1'b0;
        wr_en2 <= 1'b0;
    end
    else if(rd_en_posedge == 1'b1) begin    //rd_en信号到来后时启动FIFO1写入，禁用FIFO2
        wr_en1 <= 1'b1;
        wr_en2 <= 1'b0;
    end
    else if(full1 == 1'b1) begin   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        wr_en1 <= 1'b0;
        wr_en2 <= 1'b1;
    end       
    else if(full2 == 1'b1) begin   //FIFO2写满后使能FIFO1写入，FIFO2开始读出
        wr_en1 <= 1'b1;
        wr_en2 <= 1'b0;
    end
    else begin   //在数据写入和读取过程中保持使能信号
        wr_en1 <= wr_en1;
        wr_en2 <= wr_en2;
    end

/*在读时钟rd_clk下交替读取两个FIFO*/
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n) begin         //初始化时两个FIFO中都没有数据，因此全都读失能
        rd_en1 <= 1'b0;
        rd_en2 <= 1'b0;
    end
    else if(full1 == 1'b1) begin   //FIFO1写满后使能FIFO2写入，FIFO1开始读出
        rd_en1 <= 1'b1;
        rd_en2 <= 1'b0;
    end       
    else if(full2 == 1'b1) begin   //FIFO2写满后使能FIFO1写入，FIFO2开始读出
        rd_en1 <= 1'b0;
        rd_en2 <= 1'b1;
    end
    else begin      //在数据写入和读取过程中保持使能信号
        rd_en1 <= rd_en1;
        rd_en2 <= rd_en2;
    end

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
always@(posedge wr_clk or negedge rst_n)    
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
    .wr_addr     (wr_addr1),
    .rd_addr     (rd_addr1),
    .rd_out      (rd_out1) 
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
    .wr_addr     (wr_addr2),
    .rd_addr     (rd_addr2),
    .rd_out      (rd_out1)   
);

endmodule