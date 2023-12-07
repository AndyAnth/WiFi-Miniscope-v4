module async_ram#(
    parameter   data_width = 8,
    parameter   data_depth = 30,
    parameter   addr_width = 14,
    parameter   package_size = 10  //����Ӧ����38912
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
            wr_addr <= 1'b0;    //��д�����дָ�����׼����ͷд
        else 
            wr_addr <= wr_addr;
   end

always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            rd_addr <= 1'b0;
        else if(rd_en && (~rd_out))
            rd_addr <= rd_addr + 1;
        else if(rd_out)
            rd_addr <= 1'b0;    //�������Ѷ�ָ�����׼����ͷ��
        else 
            rd_addr <= rd_addr;
   end

always@(posedge rd_clk or negedge rst_n)
   begin
      if(!rst_n)
         valid <= 1'b0;
      else if(rd_en && (~rd_out))
         valid <= 1'b1;
      else 
         valid <= 1'b0;
   end

//����Ͱ�FIFO���ܳ��ȸı��ˣ�����������RAM����
assign full = (wr_addr == data_depth) ? 1 : 0;

//��־�Ѿ���FIFO�е����ݶ�������
assign rd_out  = (rd_addr == data_depth) ? 1 : 0;

//дָ��Ϊ0��ʾFIFO�ǿյ�
assign empty = (wr_addr == 1'b0) ? 1 : 0;

endmodule