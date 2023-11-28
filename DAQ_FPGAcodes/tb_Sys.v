`timescale  1ns/1ns

module  tb_Sys#(
                 parameter   data_width = 8,
                 parameter   data_depth = 600,
                 parameter   addr_width = 12,
                 parameter   row_depth  = 304,
                 parameter   row_num = 8
);


reg             sck         ;

reg             clk         ;
reg             rst_n       ;

reg            data_in0    ;
reg            data_in1    ;
reg            data_in2    ;
reg            data_in3    ;
reg            data_in4    ;
reg            data_in5    ;
reg            data_in6    ;
reg            data_in7    ;
reg            pclk     ;  
reg            vsync ;  
reg            hsync  ;  
//reg            start_intr ;
wire    [7:0]   data_out    ;
wire            rd_empty    ;
wire            wr_full     ;
wire     [7:0]   data_in     ;  
wire             miso        ;   
wire     [2:0]   cnt_bit     ;   
wire     [2:0]   state       ;
wire             daq_clk     ;
wire     [2:0]   sck_cnt     ;
wire             start_trans ;
wire            valid       ;
wire             rd_clk      ;
//wire            pro_linevalid1;
//wire            pro_linevalid2;
wire   [addr_width-1:0]  wr_addr;//RAM ��ַ
wire   [addr_width-1:0]  rd_addr;
/*
wire            cs_line_set;
wire    [9:0]   rec_cnt;
wire    [9:0]   send_cnt;

wire   [9:0] rec_cnt_index;
wire   [9:0] rec_comp_index;

wire      cs_line_set_pre;

wire  [9:0]    rec_cnt_ram_revel;
wire   [9:0] rec_send_comp_revel;

wire     [15:0]   sent_cnt;

wire   [3:0]   cs_line_cnt;

wire         cs_multi_line_intr;

wire    clk_us;
wire    [5:0]   clk_us_cnt;

wire   [3:0]  duty_cnt;
wire     state_flag;

wire    multi_line_flag;
wire    cs_out;

wire     [7:0]   delay_cnt;
wire    delay_flag;

wire     [7:0]   pre_delay_cnt; //用来产生延时
wire     pre_delay_flag;
wire     [7:0]  pos_delay_cnt;
wire        pos_delay_flag; */
wire        intr_out ;
reg            cs_n ;
/*
wire    package_ready;
wire    finish_trans; 

wire    start_intr;

wire    [9:0]  package_cnt;
wire    [9:0]  finish_cnt;

wire     cs_pos_edge;

wire    cs_p;
wire     cs_n_posedge;

wire    pos_delay_start;

wire    first_pre_delay_start;

wire     pos_start_intr;
wire     start_intr_posedge;*/

//ʱ�ӡ���λ�ź�
initial
    begin
        //cs_n = 1;
        clk      = 0;
        sck      = 0;
        rst_n    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;
        pclk     = 0;
        vsync    = 0;
        hsync    = 0;
        cs_n = 1;

        #150
        rst_n   =  1;
        //cs_n = 0;
        //start_intr = 1;

        #150
        //pclk     = 1;
        vsync   = 1;
        hsync   = 1;
        data_in0 = 1;

        #30
        data_in0 = 0;
        data_in1 = 1;

        #30
        data_in2 = 1;
        data_in1 = 0;

        #30
        data_in3 = 1;
        data_in2 = 0;
        data_in6 = 1;

        #30
        data_in4 = 1;
        data_in3 = 0;
        data_in6 = 0;

        #30
        data_in5 = 1;
        data_in4 = 0;

        #30
        data_in6 = 1;
        data_in5 = 0;
        data_in1 = 1;

        #30
        data_in1 = 0;
        data_in7 = 1;
        data_in6 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        data_in6 = 1;
        data_in7 = 0;

        #30
        data_in5 = 1;
        data_in6 = 0;

        #30
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;
        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        //#15
        //pclk = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        cs_n = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        vsync = 0;

        #150
        vsync    = 1;
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        //#15
        //pclk = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        vsync = 0;

        #150
        //pclk     = 1;
        vsync   = 1;
        hsync   = 1;
        data_in0 = 1;

        #30
        data_in0 = 0;
        data_in1 = 1;

        #30
        data_in2 = 1;
        data_in1 = 0;

        #30
        data_in3 = 1;
        data_in2 = 0;
        data_in6 = 1;

        #30
        data_in4 = 1;
        data_in3 = 0;
        data_in6 = 0;

        #30
        data_in5 = 1;
        data_in4 = 0;

        #30
        data_in6 = 1;
        data_in5 = 0;
        data_in1 = 1;

        #30
        data_in1 = 0;
        data_in7 = 1;
        data_in6 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        data_in6 = 1;
        data_in7 = 0;

        #30
        data_in5 = 1;
        data_in6 = 0;

        #30
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;
        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        cs_n = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        //#15
        //pclk = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        vsync = 0;

        #150
        vsync    = 1;
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        cs_n  = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        //#15
        //pclk = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        vsync = 0;

        #150
        //pclk     = 1;
        vsync   = 1;
        hsync   = 1;
        data_in0 = 1;

        #30
        data_in0 = 0;
        data_in1 = 1;

        #30
        data_in2 = 1;
        data_in1 = 0;

        #30
        data_in3 = 1;
        data_in2 = 0;
        data_in6 = 1;

        #30
        data_in4 = 1;
        data_in3 = 0;
        data_in6 = 0;

        #30
        data_in5 = 1;
        data_in4 = 0;

        #30
        data_in6 = 1;
        data_in5 = 0;
        data_in1 = 1;

        #30
        data_in1 = 0;
        data_in7 = 1;
        data_in6 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        data_in6 = 1;
        data_in7 = 0;

        #30
        data_in5 = 1;
        data_in6 = 0;

        #30
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;
        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #30
        hsync    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;
        data_in3 = 0;
        data_in4 = 0;
        data_in5 = 0;
        data_in6 = 0;
        data_in7 = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        //#15
        //pclk = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        vsync = 0;

        #150
        vsync    = 1;
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        //#15
        //pclk = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        //vsync = 0;

        #150
        hsync    = 1;
        data_in7 = 1;

        #30
        //pclk = 1;
        data_in6 = 1;
        data_in7 = 0;

        #30
        //pclk = 1;
        data_in5 = 1;
        data_in6 = 0;

        #30
        //pclk = 1;
        data_in4 = 1;
        data_in5 = 0;

        #30
        //pclk = 1;
        data_in3 = 1;
        data_in4 = 0;

        #30
        //pclk = 1;
        data_in2 = 1;
        data_in3 = 0;

        #30
        //pclk = 1;
        data_in1 = 1;
        data_in2 = 0;

        #30
        //pclk =1;
        data_in0 = 1;
        data_in1 = 0;

        #15
        hsync = 0;
        vsync = 0;

        cs_n  = 1;

        #2700
        cs_n  = 0;

        #7600
        cs_n  = 1;

    end

always  #5 clk <=  ~clk;
always  #15 pclk <=  ~pclk;
always  #10 sck <=  ~sck;

//-------------spi_flash_erase-------------
Sys#(
    .data_width (8),
    .data_depth (150),
    .addr_width (12),
    .row_depth  (304),
    .colume_width  (304),
    .row_num     (8)
)Sys_inst
(
    .sys_clk    (clk        ),  //ϵͳʱ�ӣ�Ƶ��50MHz
    .sys_rst_n  (rst_n      ),  //��λ�ź�,�͵�ƽ��Ч
    .data_in0   (data_in0   ),
    .data_in1   (data_in1   ),
    .data_in2   (data_in2   ),
    .data_in3   (data_in3   ),
    .data_in4   (data_in4   ),
    .data_in5   (data_in5   ),
    .data_in6   (data_in6   ),
    .data_in7   (data_in7   ),

    .clk_out          (pclk),
    .frame_vaild      (vsync),
    .line_vaild       (hsync),
    //.start_intr      (start_intr),

    .data_out   (data_out),
    .rd_empty   (rd_empty),
    .wr_full    (wr_full),

    .data_in    (data_in) ,
    .cs_n       (cs_n)    ,
    .sck        (sck)     ,
    .cs_line_set     (cs_line_set)  ,
    .miso       (miso)    ,
    .cnt_bit    (cnt_bit) ,
    .state      (state)   ,
    .daq_clk    (daq_clk) ,
    .sck_cnt    (sck_cnt) ,  
    .start_trans(start_trans) ,  
    .valid      (valid) ,
    .rd_clk     (rd_clk)    ,
    //.pro_linevalid1(pro_linevalid1),
    //.pro_linevalid2(pro_linevalid2),
    .wr_addr            (wr_addr        ),
    .rd_addr            (rd_addr        ),
    //.rec_cnt    (rec_cnt),
    /*.send_cnt   (send_cnt),
    .cs_line_set_pre(cs_line_set_pre),
    .rec_cnt_index(rec_cnt_index),
    .rec_comp_index(rec_comp_index),
    .rec_cnt_ram_revel(rec_cnt_ram_revel),
    .rec_send_comp_revel(rec_send_comp_revel),
    sent_cnt(sent_cnt),
    .cs_line_cnt(cs_line_cnt),
    .cs_multi_line_intr(cs_multi_line_intr),
    .clk_us(clk_us),
    .clk_us_cnt(clk_us_cnt),
    .duty_cnt(duty_cnt),
    .state_flag(state_flag),
    .multi_line_flag(multi_line_flag),
    .cs_out(cs_out),
    .pre_delay_cnt  (pre_delay_cnt ),  
    .pre_delay_flag (pre_delay_flag),
    .pos_delay_cnt  (pos_delay_cnt),
    .pos_delay_flag (pos_delay_flag),*/
    .intr_out       (intr_out)
    /*.delay_cnt      (delay_cnt),
    .delay_flag     (delay_flag),
    .package_ready  (package_ready),
    .finish_trans   (finish_trans),
    .start_intr     (start_intr ),
    .package_cnt    (package_cnt),
    .finish_cnt     (finish_cnt),
    .cs_pos_edge    (cs_pos_edge),
    .cs_pre_edge    (cs_pre_edge ),
    .cs_n_posedge   (cs_n_posedge),
    .cs_n_negedge   (cs_n_negedge),
    .cs_p           (cs_p),
    .pos_delay_start (pos_delay_start),
    .first_pre_delay_start(first_pre_delay_start),
    .pos_start_intr (pos_start_intr),
    .start_intr_posedge (start_intr_posedge)*/
);


endmodule