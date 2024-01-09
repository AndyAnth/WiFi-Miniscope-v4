module async_fifo#(
      parameter   data_width   =  8    ,
      parameter   package_size =  10 //8行图像 (4864)
)
(
      input                           rst_n     ,
      input                           wr_clk    ,
      input                           wr_en     ,
      input        [data_width-1:0]   din       ,         
      input                           rd_clk    ,
      input                           rd_en     ,
      output   reg                    valid     ,
      output   wire [data_width-1:0]  dout      ,
      output   wire                   empty     ,
      output   wire                   full      ,
      output   wire [12:0]            words     ,
      output   reg                    package_ready //指示待发送数据包已准备好
   
    );

fifo_async	fifo_async_inst (
	.data 		( din	 ),
	.rdclk 		( rd_clk ),
	.rdreq 		( rd_en  ),
	.wrclk 		( wr_clk ),
	.wrreq 		( wr_en  ),
	.q 			( dout	 ),
	.rdempty 	( empty  ),
	.wrusedw 	( words  ),
	.wrfull 	( full   )
	);

always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        package_ready <= 1'b0;
    else if((words/package_size != 1'b0) && (words%package_size == 1'b0))
        package_ready <= 1'b1;
    else 
        package_ready <= 1'b0;
end

always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        valid <= 1'b0;
    else  if(empty!= 1'b1)
        valid <= 1'b1;
    else 
        valid <= 1'b0;
end

endmodule