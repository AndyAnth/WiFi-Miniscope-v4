module fifo_async#(
      parameter   data_width = 8,
      parameter   data_depth = 600,
      parameter   addr_width = 12,
      parameter   package_size = 10  //正常应该是38912
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
      input    wire                   spi_sck,
      input    wire                   cs_n,
      input    wire                   finish_trans,
      output   reg                    empty,
      output   reg                    full,
      output   reg                    package_ready, //指示待发送数据包已准备好

      output   wire [addr_width-1:0]  wr_addr      ,//RAM 地
      output   wire [addr_width-1:0]  rd_addr      
    );


reg    [addr_width:0]    wr_addr_ptr;//地址指针，比地址多一位，MSB用于检测在同一圈
reg    [addr_width:0]    rd_addr_ptr;

reg    [addr_width:0]    wr_addr_gray;//地址指针对应的格雷码
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
      wr_addr_gray = (wr_addr_ptr >> 1) ^ wr_addr_ptr; //这还没解决
//=========================================================write fifo 


always@(posedge wr_clk or negedge rst_n)
    begin//://write_ram
			 //integer i; 
       if(!rst_n)
         fifo_ram[wr_addr] <= 1'b0;
				 //for( i = 0; i < data_depth; i = i + 1 ) begin:write_ram_init
          	 //fifo_ram[i] <= 'h0;//fifo复位后输出总线上是0，并非ram中真的复位。可无
				 //end//write_ram_init
             //fifo_ram <= 1'b0;
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
            dout <=  dout;//fifo复位后输出总线上是0，并非ram中真的复位，只是让总线为0；
            valid <= 1'b0;
         end
   end
/*
reg pos_valid2;
always@(posedge spi_sck or negedge rst_n)
   begin
      if(!rst_n)
            pos_valid2 <= 1'b0;
      else

            pos_valid2 <= pos_valid1;
   end

always@(posedge spi_sck or negedge rst_n)
   begin
      if(!rst_n)
            valid <= 1'b0;
      else

            valid <= pos_valid2;
   end
*/
//=============================================================格雷码同步化
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

//配置包使能信号，标志FIFO中已存入一包大小数据，在信号准备好后读出，能够解决FIFO读空问题
always@(posedge wr_clk or negedge rst_n)  //该模块时钟是wr_clk，可能会存在潜在问题
   if(!rst_n)
      package_ready <= 1'b0;
   else if(((wr_addr_ptr-rd_addr_ptr)/package_size != 1'b0) && ((wr_addr_ptr-rd_addr_ptr)%package_size == 1'b0))
      package_ready <= 1'b1;        //在读写地址指针相差package_size的长度时马上拉高标志信号
   else
      package_ready <= 1'b0;     //标志信号只持续一个sys_clk周期

//assign full = (wr_addr_gray == {~(rd_addr_gray_d2[addr_width-:2]),rd_addr_gray_d2[addr_width-2:0]}) ;//高两位不同
//assign empty = ( rd_addr_gray == wr_addr_gray_d2 );

endmodule

