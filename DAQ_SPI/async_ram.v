module async_ram#(
    parameter   data_width = 8,
    parameter   data_depth = 60,
    parameter   addr_width = 14,
    parameter   package_size = 60  //正常应该是38912
)
(
    input                           rst_n  ,
    input                           wr_clk ,
    input                           wr_en  ,
    input        [data_width-1:0]   din    ,         
    input                           rd_clk ,
    input                           rd_en  ,

    output   reg                    valid  ,
    output   wire [data_width-1:0]  dout   ,
    output   wire                   empty  ,
    output   wire                   full   ,
    output   reg  [addr_width-1:0]  wr_addr,
    output   reg  [addr_width-1:0]  rd_addr,
    output   wire                   rd_out    
);

//wire                  rd_out  ;
//reg [addr_width-1:0]  wr_addr ;
//reg [addr_width-1:0]  rd_addr ;

fifo_ram	fifo_ram_inst (
	.data 		( din       ),
	.rdaddress 	( rd_addr   ),
	.rdclock 	( rd_clk 	),
	.rden 		( rd_en 	),
	.wraddress 	( wr_addr   ),
	.wrclock 	( wr_clk 	),
	.wren 		( wr_en 	),
	.q 			( dout 		)
);

always@(posedge wr_clk or negedge rst_n)
   begin
        if(!rst_n)
            wr_addr <= 1'b0;
        else if(wr_en && (~full))
            wr_addr <= wr_addr + 1;
        else if(full)
            wr_addr <= 1'b0;    //当写满后把写指针归零准备从头写
        else 
            wr_addr <= wr_addr;
   end

always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            rd_addr <= 1'b0;
        else if((rd_en) && (~rd_out))
            rd_addr <= rd_addr + 1;
        else if((rd_out) && (~rd_en)) //这个是防止在另一个FIFO写入的时候，当前FIFO读空后会重置rd_addr而从头开始读取
            rd_addr <= 1'b0;    //当读完后把读指针归零准备从头读
        else
            rd_addr <= rd_addr;
   end

reg     valid_pre;
always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            valid_pre <= 1'b0;
        else if(rd_en && (~rd_out))
            valid_pre <= 1'b1;
        else 
            valid_pre <= 1'b0;
   end

//把valid信号打一拍来配合dout的时序(dout从RAM中读出要滞后rd_addr一个时钟周期)
always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            valid <= 1'b0;
        else 
            valid <= valid_pre;
   end

//接收数据计数器，计数一共收到多少数据
reg  wr_cnt;
always@(posedge wr_clk or negedge rst_n)
   begin
        if(!rst_n)
            wr_cnt <= 1'b0;
        else if(wr_en && (~full))
            wr_cnt <= wr_cnt + 1'b1;
        else if(rd_out)
            wr_cnt <= 1'b0;
        else
            wr_cnt <= wr_cnt;
   end

//这里就把FIFO的总长度改变了，不用受限于RAM容量
assign full = (wr_addr == data_depth);  
//FULL信号波形上早于(wr_addr==data_depth)一个wr_clk周期，正好配合wr_en的变化

//标志已经把FIFO中的数据都读空了
assign rd_out  = (rd_addr == data_depth);

//写指针为0表示FIFO是空的(但现在的逻辑是标志读空)
assign empty = (~valid);

endmodule