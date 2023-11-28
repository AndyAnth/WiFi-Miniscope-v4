`timescale  1ns/1ns

/*module  tb_async_fifo();

parameter   data_width  = 16;

reg                         rst    ;
reg                         wr_clk ;
reg                         wr_en  ;
reg  [data_width-1:0]       din    ;         
reg                         rd_clk ;
reg                         rd_en  ;  
wire                        valid  ;
wire [data_width-1:0]       dout   ;
wire                        empty  ;
wire                        full   ;

initial
    begin
        rst     <=  0;
        wr_clk  <=  0;
        rd_clk  <=  0;
        wr_en   <=  0;
        din     <=  0;
        rd_en   <=  0;

        #100
        rst   <=  1;
        #1000
        wr_en   <=  1;
        //wr_clk  <=  1;
        din <= 16'd0000_1100_0010_0001;
        
        #20
        //rd_clk  <=  1;
        rd_en   <=  1;

    end

always  #10 wr_clk <=  ~wr_clk;
always  #10 rd_clk <=  ~rd_clk;



//-------------spi_flash_erase-------------
fifo_async
#(
                .data_width     (16 ),
                .data_depth     (256),
                .addr_width     (8  )
)fifo_async_inst
(
                .rst    (rst    ),
                .wr_clk (wr_clk ),
                .wr_en  (wr_en  ),
                .din    (din    ),         
                .rd_clk (rd_clk ),
                .rd_en  (rd_en  ),
                .valid  (valid  ),
                .dout   (dout   ),
                .empty  (empty  ),
                .full   (full   )
    );


endmodule*/
/*
module asyn_fifo_tb;
 
parameter DATA_W           =   8      ;
parameter ADDR_W           =   4      ;
parameter data_hight       =   16     ;
 
reg                        wr_clk     ;
reg                        rd_clk     ;
reg                        rst_n      ;
reg                        wr_en      ;
reg    [DATA_W-1:0]        wr_data    ;
reg                        rd_en      ; 
 
wire   [DATA_W-1:0]        rd_data    ;
wire                       empty      ;
wire                       full       ;
 
 
asyn_fifo u_FIFO_asyn 
(
  .data_out           (rd_data),           
  .data_in            (wr_data),
  .wr_clk             (wr_clk) ,
  .rst_n              (rst_n)  ,
  .full               (full)   ,
  .empty              (empty)  ,
  .rd_clk             (rd_clk) ,
  .rd_en              (rd_en)  ,
  .wr_en              (wr_en)  
);
 
always #10 wr_clk = ~wr_clk;
always #5  rd_clk = ~rd_clk;
 
 initial begin
 
   wr_clk    = 1;
   rd_clk    = 0;
   rst_n     = 0;
   wr_en     = 0;
   wr_data   = 0;
   rd_en     = 0;
 
   #101;
   rst_n = 1;
 
   #20;
   gen_data;
   
   @(posedge rd_clk);
   rd_en=1;
   #1000 $finish;
 end
 
  task gen_data;
     integer i;
     begin
         for(i=0;i<15;i=i+1)
           begin
            wr_en      =  1;
            wr_data    =  i;
            #20;
           end
           wr_en   = 0;
           wr_data = 0;
     end
 endtask

  
initial begin 
	$fsdbDumpfile("asy_fifo.fsdb");
	$fsdbDumpvars(0);
 
end

endmodule	*/		

module fifo_async_tb();
                        
  reg                 tb_rst_n  ;  
  reg                 tb_wr_clk ;                 
  reg                 tb_wr_en  ;              
  reg   [31:0]        tb_din    ;               
  reg                 tb_rd_clk ;                     
  reg                 tb_rd_en  ;                    
  wire                tb_valid  ;                      
  wire  [31:0]        tb_dout   ;                     
  wire                tb_empty  ;                        
  wire                tb_full   ;                      

  task delay;
    input [31:0] num;
    begin
      repeat(num) @(posedge tb_wr_clk);
      #1;
    end
  endtask

  task delay1;
    input [31:0] num;
    begin
      repeat(num) @(posedge tb_rd_clk);
      #1;
    end
  endtask

  initial begin
    tb_wr_clk = 0;
  end
  always #40 tb_wr_clk = ~tb_wr_clk;

  initial begin
    tb_rd_clk = 0;
  end
  always #10 tb_rd_clk = ~tb_rd_clk;

  initial begin
    tb_rst_n = 1;
    delay(1);
    tb_rst_n = 0;
    delay(1);
    tb_rst_n = 1;
  end

  initial begin
    $dumpfile(" async_fifo_tb.vcd ");
    $dumpvars();
  end

  initial begin
    tb_wr_en = 0;
    tb_din = 0;
    tb_rd_en = 0;
    delay(3);
    // write data
    tb_wr_en = 1;
    tb_din = 32'haaaa;
    delay(1);
    tb_wr_en = 0;
    delay(5);
    // read data, empty
    tb_rd_en = 1;
    delay1(1);
    tb_rd_en = 0;
    delay1(5);
    // write data1
    tb_wr_en = 1;
    tb_din = 32'hbbbb;
    delay(1);
    tb_wr_en = 0;
    delay(5);
    // write data2
    tb_wr_en = 1;
    tb_din = 32'hcccc;
    delay(1);
    tb_wr_en = 0;
    delay(5);
    // write data3
    tb_wr_en = 1;
    tb_din = 32'hdddd;
    delay(1);
    tb_wr_en = 0;
    delay(5);
    // write data4, full
    tb_wr_en = 1;
    tb_din = 32'heeee;
    delay(1);
    tb_wr_en = 0;
    delay(5);
    // read data1
    tb_rd_en = 1;
    delay1(1);
    tb_rd_en = 0;
    delay1(5);
    // read data2
    tb_rd_en = 1;
    delay1(1);
    tb_rd_en = 0;
    delay1(5);
    // read data3
    tb_rd_en = 1;
    delay1(1);
    tb_rd_en = 0;
    delay1(5);
    // read data4, empty
    tb_rd_en = 1;
    delay1(1);
    tb_rd_en = 0;
    delay1(5);
    delay(5);
    $finish;
  end
fifo_async#(
                 .data_width(32) ,
                 .data_depth(4 ) ,
                 .addr_width(2 )  
) dut1_fifo_async
(
  .rst_n ( tb_rst_n  )  ,
  .wr_clk( tb_wr_clk )  ,
  .wr_en ( tb_wr_en  )  ,
  .din   ( tb_din    )  ,         
  .rd_clk( tb_rd_clk )  ,
  .rd_en ( tb_rd_en  )  ,
  .valid ( tb_valid  )  ,
  .dout  ( tb_dout   )  ,
  .empty ( tb_empty  )  ,
  .full  ( tb_full   )            
    );


endmodule
