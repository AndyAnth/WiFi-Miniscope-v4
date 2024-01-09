module async_ram#(
    parameter   data_width = 8,
    parameter   data_depth = 11552,
    parameter   addr_width = 14,
    parameter   package_size = 11552  
)
(
    input                           sys_clk,
    input                           rst_n  ,
    input                           wr_clk ,
    input                           wr_en  ,
    input        [data_width-1:0]   din    ,         
    input                           rd_clk ,
    input                           rd_en  ,
    input                           intr_out,

    output   reg                    valid  ,
    output   wire [data_width-1:0]  dout   ,
    output   wire                   empty  ,
    output   reg                    full   ,
    output   reg  [addr_width-1:0]  wr_addr,
    output   reg  [addr_width-1:0]  rd_addr,
    output   reg                    rd_out 
);

//wire                  rd_out  ;
//reg [addr_width-1:0]  wr_addr ;
//reg [addr_width-1:0]  rd_addr ;
reg  rd_out_flag ;

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
        else if(wr_en)
            wr_addr <= wr_addr + 1'b1;
        else if(!wr_en)
            wr_addr <= 1'b0;    //��д�����дָ�����׼����ͷд
        else 
            wr_addr <= wr_addr;
   end

always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            rd_addr <= 1'b0;
        else if((rd_en) && (!rd_out))
            rd_addr <= rd_addr + 1'b1;
        else if((!rd_en) || (rd_out)) //����Ƿ�ֹ����һ��FIFOд���ʱ�򣬵�ǰFIFO���պ������rd_addr����ͷ��ʼ��ȡ
            rd_addr <= 1'b0;    //�������Ѷ�ָ�����׼����ͷ��
        else
            rd_addr <= rd_addr;
   end

reg     valid_pre;
always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            valid_pre <= 1'b0;
        else if(rd_en && (!rd_out))
            valid_pre <= 1'b1;
        else
            valid_pre <= 1'b0;
   end

//��valid�źŴ�һ�������dout��ʱ��(dout��RAM�ж���Ҫ�ͺ�rd_addrһ��ʱ������)
always@(posedge rd_clk or negedge rst_n)
   begin
        if(!rst_n)
            valid <= 1'b0;
        else 
            valid <= valid_pre;
   end

//����Ͱ�FIFO���ܳ��ȸı��ˣ�����������RAM����
always @(posedge wr_clk or negedge rst_n) begin
    if(!rst_n)
        full <= 1'b0;
    else if(wr_addr == (data_depth-1))
        full <= 1'b1;
    else
        full <= 1'b0;
end

//wire full_pre;

//assign full = (wr_addr == data_depth);  

//FULL�źŲ���������(wr_addr==data_depth)һ��wr_clk���ڣ��������wr_en�ı仯
//delayn#(.n(5)) delayn_inst(.clk(sys_clk), .rst_n(rst_n), .in(full_pre), .out(full));

//��־�Ѿ���FIFO�е����ݶ�������
always @(posedge rd_clk or posedge intr_out) begin
    if(intr_out)
        rd_out <= 1'b0;
    else if(rd_addr == (data_depth-1))
        rd_out <= 1'b1;
    else
        rd_out <= rd_out;
end

//assign rd_out  = (rd_addr == data_depth);

//дָ��Ϊ0��ʾFIFO�ǿյ�(�����ڵ��߼��Ǳ�־����)
assign empty = (~valid);

endmodule