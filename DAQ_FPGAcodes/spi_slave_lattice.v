`timescale  1ns/1ns
module  spi_slave
(
    //input   wire            sys_clk     ,   //ϵͳʱ�ӣ�Ƶ��50MHz
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч
    input   wire            data_in0    ,
    input   wire            data_in1    ,
    input   wire            data_in2    ,
    input   wire            data_in3    ,
    input   wire            data_in4    ,
    input   wire            data_in5    ,
    input   wire            data_in6    ,
    input   wire            data_in7    ,

    input   wire            pclk        ,
    input   wire            vsync       ,
    input   wire            hsync       ,
    
    //output  wire    [7:0]   data_out,
    //output  reg             rd_req,
    //output  reg             wr_req,
    //output  wire            rd_empty,
    //output  wire            wr_full,

    //output  reg    [7:0]    data_in     ,
    input   wire            cs_n        ,   //Ƭѡ�ź�
    input   wire            sck         ,   //����ʱ��
    output  reg             mosi        ,   //���������������
    output  reg             handshake_start      //��ʼ�����־�ź�
    //output  reg             handshake_end   ,   //���������־�ź�
    //output  reg     [2:0]   cnt_bit     ,    //���ؼ�����
    //output  reg     [3:0]   state       ,
    //output  reg             daq_clk     ,
    //output  reg  [2:0]      sck_cnt,
    //output  reg             rd_clk

);

//parameter define
parameter   IDLE    =   4'b0001 ,   //��ʼ״̬
            WR_EN   =   4'b0010;   //д״̬

wire    [7:0]   data_out ;
reg             rd_req   ;
reg             wr_req   ;
wire            rd_empty ;
wire            wr_full  ;
reg     [7:0]   data_in  ;

reg             handshake_end; 
reg     [2:0]   cnt_bit ;
reg     [3:0]   state   ;
reg             daq_clk ;
reg     [2:0]   sck_cnt ;
reg             rd_clk  ;

wire            clk_ref;
wire            sys_clk;

wire    clkhf_en;
wire    clkhf_pu;
assign  clkhf_en = 1'b1;
assign  clkhf_pu = 1'b1;

//�����ڲ�����ʱ��
HSOSC
#(
 .CLKHF_DIV ("0b00")
) OSCInst0 (
 .CLKHFEN (clkhf_en ),
 .CLKHFPU (clkhf_pu ),
 .CLKHF   (clk_ref  )
);

/*
//48MHz->50MHz Convert
PLL PLLInst0
(
    ref_clk_i   (clk_ref  ),
    rst_n_i     (sys_rst_n),
    outcore_o   (sys_clk  ),
    outglobal_o ()
);*/



//reg     daq_clk;
//
//ͨ��pclk��sys_clk�´��Ĳ���һ������ʱ��daq_clk����֤����ʱ�����Ѿ��ȶ�
//����������f_pclk < f_sys_clk
always@(posedge clk_ref or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        daq_clk <= 1'b0;
    else if((pclk == 1'b1) && (state == WR_EN))
        daq_clk <= 1'b1;
    else
        daq_clk <= 1'b0;
end

//reg  [2:0]  sck_cnt;
//reg         rd_clk;
//cnt_bit:�ߵ�λ�Ե�������mosi���
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  3'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 3'd7)
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//��pclkΪʱ�Ӳ�������data0~7�ź�
always @(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        data_in <= 0;
    else begin
        data_in[0] <= data_in0;
        data_in[1] <= data_in1;
        data_in[2] <= data_in2;
        data_in[3] <= data_in3;
        data_in[4] <= data_in4;
        data_in[5] <= data_in5;
        data_in[6] <= data_in6;
        data_in[7] <= data_in7;
    end
end

wire    valid;

//���fifo���е��������������ӳ�һ��ʱ�䣬�һᶪʧ��ʼ����
fifo_async#(
    .data_width (8),
    .data_depth (150),
    .addr_width (12)
)fifo_async_inst
(
    .rst_n  (sys_rst_n ),
    .wr_clk (daq_clk   ),
    .wr_en  (1'b1    ),
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (rd_req    ),
    .valid  (valid     ),
    .dout   (data_out  ),
    .empty  (rd_empty  ),
    .full   (wr_full   )
    );
/*
fifo	fifo_inst (
	.data    ( data_in   ),
	.rdclk   ( sck       ),
	.rdreq   ( rd_req    ),
	.wrclk   ( daq_clk   ),
	.wrreq   ( wr_req    ),
	.q       ( data_out  ),
	.rdempty ( rd_empty  ),
	.wrfull  ( wr_full   )
	);*/


//cnt_bit:�ߵ�λ�Ե�������mosi���
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <=  3'd0;
    else
        cnt_bit <=  cnt_bit + 1'b1;


//state:����ʽ״̬����һ�Σ�״̬��ת
always@(posedge clk_ref or  negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        state   <=  IDLE;
        //wr_req <= 1'b0;
    end
    else begin
        state   <=  WR_EN;
        //wr_req <= 1'b1;
    end
end

always@(posedge daq_clk or  negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        wr_req <= 1'b0;
    else if(state == WR_EN)
        wr_req <= 1'b1;
    else
        wr_req <= wr_req;
end


//��ʼ��FIFO��дʹ���źţ�rd_req�ź���״̬��ΪIDLE�ĺ�һ��
always@(posedge clk_ref or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_req <= 1'b0;
    else if(state == WR_EN)
        rd_req <= 1'b1;
    else
        rd_req <= 1'b0;

//mosi:����ʽ״̬���ڶ��Σ��߼����
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        mosi <= 1'b0;
    else if(state == WR_EN)
        mosi <= data_out[7-cnt_bit];    //дʹ��ָ��
    else if((state == WR_EN) && (rd_empty == 1'b1)) 
        mosi <= 8'b1111_1111;   //����һ��ȫ1���ݰ���ʾ����ͷ�������
    else    if(state == IDLE)
        mosi    <=  1'b0;

//handshake_start�ź�(���һ��sys_clk���ڣ���֤�ȶ�����)
always@(posedge clk_ref or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        handshake_start <= 1'b0;
    else if((state == WR_EN) && (cnt_bit == 3'b000))
        handshake_start <= 1'b1;
    else
        handshake_start <= 1'b0;

//handshake_end�ź�
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        handshake_end <= 1'b0;
    else if((state == WR_EN) && (cnt_bit == 3'b111))
        handshake_end <= 1'b1;
    else
        handshake_end <= 1'b0;


endmodule
