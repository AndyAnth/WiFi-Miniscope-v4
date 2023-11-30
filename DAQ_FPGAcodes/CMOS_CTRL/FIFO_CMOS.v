module FIFO_CMOS#(
      parameter   data_width = 27,
      parameter   data_depth = 600,
      parameter   addr_width = 12
)
(
      input                           rst_n,
      input                           wr_clk,
      input                           wr_en,
      input        [data_width-1:0]   din,         
      input                           rd_clk,
      input                           rd_en,
      output   reg                    valid,
      output   reg [data_width-1:0]   dout,
      output   reg                    empty,
      output   reg                    full,

      output   wire [addr_width-1:0]  wr_addr      ,//RAM ��
      output   wire [addr_width-1:0]  rd_addr      
    );


reg    [addr_width:0]    wr_addr_ptr;//��ַָ�룬�ȵ�ַ��һλ��MSB���ڼ����ͬһȦ
reg    [addr_width:0]    rd_addr_ptr;

reg    [addr_width:0]    wr_addr_gray;//��ַָ���Ӧ�ĸ�����
reg    [addr_width:0]    wr_addr_gray_d1;
reg    [addr_width:0]    wr_addr_gray_d2;
wire   [addr_width:0]    rd_addr_gray;
reg    [addr_width:0]    rd_addr_gray_d1;
reg    [addr_width:0]    rd_addr_gray_d2;


reg [data_width-1:0] fifo_ram [data_depth-1:0];

always@(*)
   if(!rst_n)
      wr_addr_gray <= 1'b0;
   else
      wr_addr_gray = (wr_addr_ptr >> 1) ^ wr_addr_ptr; //�⻹û���
//=========================================================write fifo 


always@(posedge wr_clk or negedge rst_n)
    begin//://write_ram
			 //integer i; 
       if(!rst_n)
         fifo_ram[wr_addr] <= 1'b0;
			
       else if(wr_en && (~full))
          fifo_ram[wr_addr] <= din;
       else
          fifo_ram[wr_addr] <= fifo_ram[wr_addr];  
    end//write_ram    

assign wr_addr = wr_addr_ptr[addr_width-1-:addr_width];
assign rd_addr = rd_addr_ptr[addr_width-1-:addr_width];

//reg pos_valid1;
//========================================================read_fifo
always@(posedge rd_clk or negedge rst_n)
   begin
      if(!rst_n)
         begin
            dout <= 'h0;
            valid <= 1'b0;
         end
      else if(rd_en && (~empty))
         begin
            dout <= fifo_ram[rd_addr];
            valid <= 1'b1;
         end
      else
         begin
            dout <=  dout;//fifo��λ�������������0������ram����ĸ�λ��ֻ��������Ϊ0��
            valid <= 1'b0;
         end
   end

//=============================================================������ͬ����
always@(posedge wr_clk or negedge rst_n) begin
   if(!rst_n) begin
      rd_addr_gray_d1   <= 1'b0;
      rd_addr_gray_d2   <= 1'b0;
   end
   else begin
      rd_addr_gray_d1 <= rd_addr_gray;
      rd_addr_gray_d2 <= rd_addr_gray_d1;
   end
end

always@(posedge wr_clk or negedge rst_n)
   begin
      if(!rst_n)
         wr_addr_ptr <= 'h0;
      else if(wr_en && (~full))
         wr_addr_ptr <= wr_addr_ptr + 1;
      else 
         wr_addr_ptr <= wr_addr_ptr;
   end
//=========================================================rd_clk
always@(posedge rd_clk or negedge rst_n) begin
   if(!rst_n) begin
      wr_addr_gray_d1 <= 1'b0;
      wr_addr_gray_d2 <= 1'b0;
   end
   else begin
      wr_addr_gray_d1 <= wr_addr_gray;
      wr_addr_gray_d2 <= wr_addr_gray_d1;
   end
end

always@(posedge rd_clk or negedge rst_n)
   begin
      if(!rst_n)
         rd_addr_ptr <= 'h0;
      else if(rd_en && (~empty))
         rd_addr_ptr <= rd_addr_ptr + 1;
      else 
         rd_addr_ptr <= rd_addr_ptr;
   end

//========================================================== translation gary code
//assign wr_addr_gray = (wr_addr_ptr >> 1) ^ wr_addr_ptr;
assign rd_addr_gray = (rd_addr_ptr >> 1) ^ rd_addr_ptr;

always@(*) begin
   if(rst_n == 1'b0)
      full <= 1'b0;
   else
      full <= (wr_addr_gray == {~(rd_addr_gray_d2[addr_width-:2]),rd_addr_gray_d2[addr_width-2:0]}) ;
end

always@(*) begin
   if(rst_n == 1'b0)
      empty <= 1'b0;
   else
      empty <= ( rd_addr_gray == wr_addr_gray ) ;
end


endmodule

