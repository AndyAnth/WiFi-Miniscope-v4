`timescale  1ns/1ns

module  tb_ring_fifo#(
    parameter   data_width = 8,
    parameter   data_depth = 60,
    parameter   addr_width = 13,
    parameter   package_size = 60 
);

reg            sys_clk      ;   
reg            sys_rst_n    ;  

reg                   wr_en  ;     
reg                   rd_clk ;
reg                   rd_en  ;

wire                   valid  ;
wire [data_width-1:0]  dout   ;
wire                   package_ready; 
wire                   empty  ;
wire                   empty1 ;
wire                   full1  ;
wire                   empty2 ;
wire                   full2  ;
wire                   ram_wr_sel ;
wire                   ram1_rd_sel;
wire                   ram2_rd_sel;
wire                   wr_en1 ;
wire                   wr_en2 ;
wire                   rd_en1 ;
wire                   rd_en2 ;
wire                   rd_out ;
wire                   rd_sel ;
wire [data_width-1:0]  dout1  ;
wire [data_width-1:0]  dout2  ;
wire                   valid1 ;
wire                   valid2 ;
wire                   emp_sel;  


wire            data_in0    ;
wire            data_in1    ;
wire            data_in2    ;
wire            data_in3    ;
wire            data_in4    ;
wire            data_in5    ;
wire            data_in6    ;
wire            data_in7    ;
wire            clk_out     ;  
wire            frame_vaild ;  
wire            line_vaild  ;  
wire    [2:0]   state       ;
wire    [7:0]   data_in     ;
wire            daq_clk     ;
wire    [9:0]   rec_cnt     ;

wire [addr_width-1:0]   wr_addr1;
wire [addr_width-1:0]   rd_addr1;
wire [addr_width-1:0]   wr_addr2;
wire [addr_width-1:0]   rd_addr2;


initial
    begin
        sys_clk    = 0;
        sys_rst_n  = 0;
        wr_en = 0;
        rd_clk = 0;
        rd_en = 0;

        #50 sys_rst_n  = 1;

        #50 wr_en = 1;
        rd_en = 1;

    end
/*
always@(posedge sys_clk or negedge sys_rst_n)
    if(!sys_rst_n)
        rd_en <= 1'b0;
    else if(package_ready)
        rd_en <= 1'b1;
    else if(empty1)
        rd_en <= 1'b0;
    else if(empty2)
        rd_en <= 1'b0;
    else
        rd_en <= rd_en;
*/
always  #10 sys_clk  <=  ~sys_clk;
always  #5 rd_clk   <=  ~rd_clk;


DATA_GEN#(
    .CNT20_MAX  ( 4  ),
    .CNT10_MAX  ( 9  ),
    .CNT5_MAX   ( 19 ),
    .LINE_MAX   (100 ),
    .FRAME_MAX  (2000)
) DATA_GEN_inst
(
    .sys_clk     (sys_clk    ),   //系统时钟，频率50MHz
    .sys_rst_n   (sys_rst_n  ),   //复位信号,低电平有效

    .data_in0    (data_in0   ),
    .data_in1    (data_in1   ),
    .data_in2    (data_in2   ),
    .data_in3    (data_in3   ),
    .data_in4    (data_in4   ),
    .data_in5    (data_in5   ),
    .data_in6    (data_in6   ),
    .data_in7    (data_in7   ),
    .clk_out     (clk_out    ),
    .frame_vaild (frame_vaild),
    .line_vaild  (line_vaild )
);


DAQ_sync DAQ_sync_inst
(
    .sys_clk     (sys_clk    ),   
    .sys_rst_n   (sys_rst_n  ),   
    .data_in0    (data_in0   ),
    .data_in1    (data_in1   ),
    .data_in2    (data_in2   ),
    .data_in3    (data_in3   ),
    .data_in4    (data_in4   ),
    .data_in5    (data_in5   ),
    .data_in6    (data_in6   ),
    .data_in7    (data_in7   ),

    .clk_out     (clk_out    ),  
    .frame_vaild (frame_vaild),  
    .line_vaild  (line_vaild ),  

    .state       (state      ),


    .data_in     (data_in    ),
    .daq_clk     (daq_clk    ),
    .rec_cnt     (rec_cnt    )
);

ring_fifo#(
    .data_width     (data_width) ,
    .data_depth     (data_depth),
    .addr_width     (addr_width) ,
    .package_size   (package_size)  //正常应该是38912
)ring_fifo_inst
(
    .rst_n   (sys_rst_n     ),
    .wr_clk  (daq_clk   ),
    .wr_en   (wr_en     ),
    .din     (data_in   ),         
    .rd_clk  (rd_clk    ),
    .rd_en   (rd_en     ),

    .valid           (valid        ),
    .dout            (dout     ),
    .package_ready   (package_ready), //指示待发送数据包已准备好
    .empty           (empty        ),
    .empty1          (empty1       ),
    .full1           (full1        ),
    .empty2          (empty2       ),
    .full2           (full2        ),
    .wr_en1          (wr_en1       ),
    .wr_en2          (wr_en2       ),
    .rd_en1          (rd_en1       ),
    .rd_en2          (rd_en2       ),
    .rd_out          (rd_out       ),
    .rd_sel          (rd_sel       ),
    .dout1           (dout1        ),
    .dout2           (dout2        ),  
    .valid1          (valid1       ),
    .valid2          (valid2       ),
    .emp_sel         (emp_sel      ),
    .wr_addr1       (wr_addr1),
    .rd_addr1       (rd_addr1),
    .wr_addr2       (wr_addr2),
    .rd_addr2       (rd_addr2),
    .ram_wr_sel     (ram_wr_sel),
    .ram1_rd_sel    (ram1_rd_sel),
    .ram2_rd_sel    (ram2_rd_sel)
);

endmodule