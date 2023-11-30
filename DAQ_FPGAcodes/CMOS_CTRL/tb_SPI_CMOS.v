`timescale  1ns/1ns

module  tb_SPI_CMOS#(
                 parameter   data_width = 27,
                 parameter   data_depth = 600,
                 parameter   addr_width = 12,
                 parameter   row_depth  = 304
);


reg             sys_clk      ;   
reg             sys_rst_n    ;   
reg             ready        ;
reg             sck_in       ;   
wire   [24:0]   data_out     ;
wire            rd_empty     ;
wire            wr_full      ;
wire   [26:0]   data_in      ;
wire   [31:0]   data_rec     ;
wire            cs_n_out_pos ;   
wire            cs_n_out_pre ;   
wire            cs_n_out     ;   
reg             cs_n_in      ;
wire    [2:0]   sck_out_cnt  ;
wire            sck_out      ;   
wire            cs_line_set  ;   
wire            mosi         ;   
reg             miso         ;
wire    [4:0]   cnt_bit      ;   
wire    [5:0]   rec_cnt_bit  ;
wire    [2:0]   state        ;
wire            daq_clk      ;
wire    [4:0]   sck_cnt      ;
wire            valid        ;
wire            rd_clk       ;
wire            flag_in      ;   
wire  [addr_width-1:0]  wr_addr;
wire  [addr_width-1:0]  rd_addr;

initial
    begin
        sys_clk    = 0;
        sck_in     = 0;
        sys_rst_n  = 0;
        ready      = 0;
        cs_n_in    = 1;
        miso       = 0;

        #50
        sys_rst_n  = 1;

        #20
        cs_n_in    = 0;
        miso       = 0; //1
        #20
        miso       = 0; //2
        #20
        miso       = 0; //3
        #20
        miso       = 0; //4
        #20
        miso       = 0; //5
        #20
        miso       = 0; //6
        #20
        miso       = 1; //7
        #20
        miso       = 0; //8
        #20
        miso       = 1; //9
        #20
        miso       = 1; //10
        #20
        miso       = 1; //11
        #20
        miso       = 0; //12
        #20
        miso       = 0; //13
        #20
        miso       = 1; //14
        #20
        miso       = 0; //15
        #20
        miso       = 1; //16
        #20
        miso       = 1; //17
        #20
        miso       = 1; //18
        #20
        miso       = 0; //19
        #20
        miso       = 0; //20
        #20
        miso       = 1; //21
        #20
        miso       = 0; //22
        #20
        miso       = 1; //23
        #20
        miso       = 1; //24
        #20
        miso       = 1; //25
        #20
        miso       = 0; //26
        #20
        miso       = 0; //27
        #20
        miso       = 1; //28
        #20
        miso       = 0; //29
        #20
        miso       = 1; //30
        #20
        miso       = 0; //31
        #20
        miso       = 0; //32
        cs_n_in    = 1;
  
        #80
        cs_n_in    = 0;
        miso       = 0; //1
        #20
        miso       = 0; //2
        #20
        miso       = 0; //3
        #20
        miso       = 0; //4
        #20
        miso       = 0; //5
        #20
        miso       = 0; //6
        #20
        miso       = 1; //7
        #20
        miso       = 0; //8
        #20
        miso       = 1; //9
        #20
        miso       = 1; //10
        #20
        miso       = 1; //11
        #20
        miso       = 0; //12
        #20
        miso       = 0; //13
        #20
        miso       = 1; //14
        #20
        miso       = 0; //15
        #20
        miso       = 1; //16
        #20
        miso       = 1; //17
        #20
        miso       = 1; //18
        #20
        miso       = 0; //19
        #20
        miso       = 0; //20
        #20
        miso       = 1; //21
        #20
        miso       = 0; //22
        #20
        miso       = 1; //23
        #20
        miso       = 1; //24
        #20
        miso       = 1; //25
        #20
        miso       = 0; //26
        #20
        miso       = 0; //27
        #20
        miso       = 1; //28
        #20
        miso       = 0; //29
        #20
        miso       = 1; //30
        #20
        miso       = 0; //31
        #20
        miso       = 0; //32
        cs_n_in    = 1;

        #60 ready  = 1;


    end

always  #10 sck_in  <=  ~sck_in;
always  #10 sys_clk <=  ~sys_clk;

//-------------spi_flash_erase-------------
SPI_CMOS#(
    .data_width    ( 27  ),
    .data_depth    ( 600 ),
    .addr_width    ( 12  ),
    .row_depth     ( 304 ),
    .colume_width  ( 304 )
)SPI_CMOS_inst
(
    .sys_clk     (sys_clk   ),   //ϵͳʱ�ӣ�Ƶ��50MHz
    .sys_rst_n   (sys_rst_n ),   //��λ�ź�,�͵�ƽ��Ч

    .ready       (ready     ),
    .sck_in      (sck_in    ),   //ESP32 �����ʱ���ź�

    .data_out    (data_out  ),
    .rd_empty    (rd_empty  ),
    .wr_full     (wr_full   ),

    .data_in     (data_in   ),
    .data_rec    (data_rec  ),
    .cs_n_out_pos(cs_n_out_pos),   //cs_n_out��sck_outʱ���´�һ�ĵõ���
    .cs_n_out_pre(cs_n_out_pre),   
    .cs_n_out    (cs_n_out   ),   //Ƭѡ�ź�
    .cs_n_in     (cs_n_in    ),
    .sck_out_cnt (sck_out_cnt),
    .sck_out     (sck_out    ),   //����ʱ��
    .cs_line_set (cs_line_set),   //���������ͬ��ʹ���ź�
    .mosi        (mosi       ),   //���������������
    .miso        (miso       ),
    .cnt_bit     (cnt_bit    ),    //���ؼ�����
    .rec_cnt_bit (rec_cnt_bit),
    .state       (state      ),
    .daq_clk     (daq_clk    ),
    .sck_cnt     (sck_cnt    ),
    .valid       (valid      ),
    .rd_clk      (rd_clk     ),
    .flag_in     (flag_in    ),   //FIFO�����־�ź�

    .wr_addr     (wr_addr    ),
    .rd_addr     (rd_addr    )

);


endmodule
