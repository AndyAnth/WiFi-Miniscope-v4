`timescale  1ns/1ns

module  spi_slave
(
    input   wire            sys_clk     ,   //ϵͳʱ�ӣ�Ƶ��50MHz
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч
    input   wire            data_in0    ,
    input   wire            data_in1    ,
    input   wire            data_in2    ,
    input   wire            data_in3    ,
    input   wire            data_in4    ,
    input   wire            data_in5    ,
    input   wire            data_in6    ,
    input   wire            data_in7    ,

    input   wire            clk_out     ,  //����ͬ���ź�
    input   wire            frame_vaild ,  //֡ͬ���ź�
    input   wire            line_vaild  ,  //��ͬ���ź�

    output  reg             start_sig   ,  //������ʼ�ź�
    
    output  wire    [7:0]   data_out    ,
    output  reg             rd_req      ,
    output  reg             wr_req      ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  reg    [7:0]    data_in     ,
    input   wire            cs_n        ,   //Ƭѡ�ź�
    input   wire            sck         ,   //����ʱ��
    output  reg             mosi        ,   //���������������
    output  reg     [2:0]   cnt_bit     ,    //���ؼ�����
    output  reg     [3:0]   state       ,
    output  reg             daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  reg             rd_clk

);

//parameter define
parameter   FOT           =   4'b0001 ,   //֡����״̬
            WR_EN_FRAME   =   4'b0010 ,   //֡ʹ��״̬
            WR_EN_LINE    =   4'b0001 ,   //��ʹ��״̬
            ROT           =   4'b0010 ;   //�п���״̬

//��pclk��sys_clk�����Ա�֤�����ȶ�����(����������F_sys_clk > F_pclk)
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        daq_clk <= 1'b0;
    else
        daq_clk <= clk_out;
end

//sck_cnt�������Ǳ�ǵ�ǰ�ѷ��Ͷ������ݣ�Ϊ�˲���rd_clkʱ��
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  3'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

//rd_sck��sck�˷�Ƶ���ʱ�ӣ�ָʾfifo�Ķ�������
always@(posedge sck or  negedge sys_rst_n)  //��sck�����ز���rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 3'd7)
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//��pclk���ĺ��rd_sckΪʱ�Ӳ�������data0~7�ź�
always @(posedge daq_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        data_in <= 0;
    else if(state == WR_EN) begin
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
    .wr_en  (wr_req    ),
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (!hsync    ),  //�����
    .valid  (valid     ),
    .dout   (data_out  ),
    .empty  (rd_empty  ),
    .full   (wr_full   )
    );


//cnt_bit:�ߵ�λ�Ե�������mosi���
always@(posedge sck or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <=  3'd0;
    else
        cnt_bit <=  cnt_bit + 1'b1;


//state:����ʽ״̬����һ�Σ�״̬��ת
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  FOT;    //frame_valid��ʹ��ʱstate����FOT״̬
    else
    case(state)
        FOT:   
                if(frame_vaild == 1'b1)  
                    state <= WR_EN_FRAME;   //frame_validʹ�ܺ�state����WR_EN_FRAME״̬�ȴ�line_validʹ��
                else
                    state <= FOT;   //frame_valid��ʹ��ʱstate����FOT״̬

        WR_EN_FRAME:  
                if(line_vaild == 1'b1)  
                    state <= WR_EN_LINE;   //frame_validʹ����line_validʹ��ʱ�����ж�ȡ״̬����ʼ���ж�ȡ����
                else if(frame_vaild == 1'b0)
                    state <= FOT;     //��WR_EN_FRAME״̬��frame_validʧ�ܺ���ת��FOT״̬
                else
                    state <= ROT;   //frame_validʹ�ܵ�line_validδʹ��ʱ����ROT״̬�ȴ�line_validʹ��

        ROT:    if(line_vaild == 1'b1)
                    state <= WR_EN_LINE; //frame_validʹ����line_validʹ��ʱ�����ж�ȡ״̬����ʼ���ж�ȡ����
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_validʧ�ܺ���ת��FOT״̬����WR_EN_LINE(frame_vaild == 1'b0)����
                                        //FOT����ͻ����Ϊ����WR_EN_LINE��ǰ����line_vaildʹ�ܣ���line_vaildʧ��Ҳ�ܽ���ROT
                else
                    state <= ROT;   //ROT��default״̬
                    
        WR_EN_LINE:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_validʹ�ܵ�line_validʧ��ʱ����ROT�п���״̬
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_validʧ��ʱֱ�ӻص�FOT״̬
                else
                    state <= WR_EN_LINE;    //���ֶ�ȡ״̬
                    
        default:    state   <=  FOT;
    endcase


//��ʼ��FIFO��дʹ���źţ�rd_req�ź���״̬��ΪIDLE�ĺ�һ��
always@(posedge sys_clk or  negedge sys_rst_n)
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
    else if(state == WR_EN && (cnt_bit == 3'b000))
        mosi <= data_out[7-cnt_bit];    //дʹ��ָ��
    else if((state == WR_EN) && (rd_empty == 1'b1)) 
        mosi <= 8'b1111_1111;   //����һ��ȫ1���ݰ���ʾ����ͷ�������
    else    if(state == IDLE)
        mosi    <=  1'b0;



endmodule



`timescale  1ns/1ns
/*���Խ��ȣ�Ŀǰrec_cnt_index��������rec_camp_index���д���Ҫ��sned_cnt��������*/
module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 600,
    parameter   addr_width = 12,
    parameter   row_depth  = 304,
    parameter   colume_width = 304,
    parameter   row_num = 8
)
(
    input   wire            sys_clk     ,   //ϵͳʱ�ӣ�Ƶ��50MHz
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч
    input   wire            data_in0    ,
    input   wire            data_in1    ,
    input   wire            data_in2    ,
    input   wire            data_in3    ,
    input   wire            data_in4    ,
    input   wire            data_in5    ,
    input   wire            data_in6    ,
    input   wire            data_in7    ,

    input   wire            clk_out     ,  //����ͬ���ź�
    input   wire            frame_vaild ,  //֡ͬ���ź�
    input   wire            line_vaild  ,  //��ͬ���ź�
    
    output  wire    [7:0]   data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,   //Ƭѡ�ź�
    input   wire            sck         ,   //����ʱ��
    output  reg             cs_set      ,   //���������ͬ��ʹ���ź�
    output  wire            miso        ,   //���������������
    output  wire    [2:0]   cnt_bit     ,    //���ؼ�����
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  reg             start_trans ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    output  reg            pro_linevalid1,
    output  reg            pro_linevalid2,
    output   wire  [addr_width:0]    wr_addr_ptr  ,//��
    output   wire  [addr_width:0]    rd_addr_ptr  ,
    output   wire  [addr_width-1:0]  wr_addr      ,//RAM ��
    output   wire  [addr_width-1:0]  rd_addr      ,
    output   wire  [addr_width:0]    wr_addr_gray ,//��  
    output   wire  [addr_width:0]    rd_addr_gray,
    output   wire  [9:0]   rec_cnt,
    output   reg   [9:0]   send_cnt,
    output   reg      cs_set_pre,
    output   reg   [9:0] rec_cnt_index,
    output   reg   [9:0] rec_comp_index,
    output   reg   [9:0] rec_cnt_ram_revel,
    output   reg   [9:0] rec_send_comp_revel,
    output   wire  [15:0]   sent_cnt,
    output   reg   [3:0]   cs_cnt,
    output   reg          cs_intr,
    output   reg         clk_us,
    output   reg [5:0]   clk_us_cnt,  
    output   reg     cs_set1,
    output   wire   [3:0]  duty_cnt,
    output   wire     state_flag
);

//parameter define
parameter   FOT           =   3'b001 ,   //֡����״̬
            WR_EN         =   3'b010 ,   //��ʹ��״̬
            ROT           =   3'b100 ;   //�п���״̬

wire  [addr_width:0]    wr_addr_gray_d1;
wire  [addr_width:0]    wr_addr_gray_d2;
wire  [addr_width:0]    rd_addr_gray_d1;
wire  [addr_width:0]    rd_addr_gray_d2;


DAQ_sync DAQ_sync_inst
(
    .sys_clk     (sys_clk    ),   //ϵͳʱ�ӣ�Ƶ��50MHz
    .sys_rst_n   (sys_rst_n  ),   //��λ�ź�,�͵�ƽ��Ч
    .data_in0    (data_in0   ),
    .data_in1    (data_in1   ),
    .data_in2    (data_in2   ),
    .data_in3    (data_in3   ),
    .data_in4    (data_in4   ),
    .data_in5    (data_in5   ),
    .data_in6    (data_in6   ),
    .data_in7    (data_in7   ),

    .clk_out     (clk_out    ),  //����ͬ���ź�
    .frame_vaild (frame_vaild),  //֡ͬ���ź�
    .line_vaild  (line_vaild ),  //��ͬ���ź�

    .state       (state      ),


    .data_in     (data_in    ),
    .daq_clk     (daq_clk    ),
    .rec_cnt     (rec_cnt    )
);

SPI_transfer SPI_transfer_inst
(
    .sck         (sck        ),   //��������Ĵ���ʱ��
    .sys_rst_n   (sys_rst_n  ),   //��λ�ź�,�͵�ƽ��Ч

    .data_in     (data_out   ),
    //.start_trans (start_trans),
    .valid       (valid      ),
    .cs_set      (cs_set_pre ),

    .miso        (miso       ),   //���������������
    .cnt_bit     (cnt_bit    ),   //���ؼ�����
    .sent_cnt    (sent_cnt   ),
    .duty_cnt    (duty_cnt   ),
    .state_flag  (state_flag )
);
//reg delaied_rd_clk;
//���fifo���е��������������ӳ�һ��ʱ�䣬�һᶪʧ��ʼ����
fifo_async#(
    .data_width (8),
    .data_depth (600),
    .addr_width (12)
)fifo_async_inst
(
    .rst_n  (sys_rst_n ),
    .wr_clk (daq_clk   ),
    .wr_en  (line_vaild),
    .din    (data_in   ),         
    .rd_clk (rd_clk    ),
    .rd_en  (start_trans),  //ע��ʱ������
    .valid  (valid     ),
    .dout   (data_out  ),
    .spi_sck(sck       ),
    .empty  (rd_empty  ),
    .full   (wr_full   ),
    .wr_addr_ptr        (wr_addr_ptr    ),
    .rd_addr_ptr        (rd_addr_ptr    ),
    .wr_addr            (wr_addr        ),
    .rd_addr            (rd_addr        ),
    .wr_addr_gray       (wr_addr_gray   ),
    .wr_addr_gray_d1    (wr_addr_gray_d1),
    .wr_addr_gray_d2    (wr_addr_gray_d2),
    .rd_addr_gray       (rd_addr_gray   ),
    .rd_addr_gray_d1    (rd_addr_gray_d1),
    .rd_addr_gray_d2    (rd_addr_gray_d2)
    );

//sck_cnt�������Ǳ�ǵ�ǰ�ѷ��Ͷ������ݣ�Ϊ�˲���rd_clkʱ��
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  3'd0;
    else
        sck_cnt <=  sck_cnt + 1'b1;

//rd_sck��sck�˷�Ƶ���ʱ�ӣ�ָʾfifo�Ķ�������
always@(posedge sck or negedge sys_rst_n)  //��sck�����ز���rd_clk
    if(sys_rst_n == 1'b0) 
        rd_clk <=  1'b0;
    else if(sck_cnt == 3'd7)
        rd_clk <=  1'b1;
    else
        rd_clk <= 1'b0;

//����cs�ź�
reg [row_depth-1:0] rec_cnt_ram [colume_width:0];
//reg [row_depth-1:0] rec_cnt_index;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt_index <= 1'b0;
    else if((pro_linevalid2 != pro_linevalid1) && (state == ROT))
        rec_cnt_index <= rec_cnt_index + 1'b1;
    else
        rec_cnt_index <= rec_cnt_index;
end

//assign rec_cnt_ram[rec_cnt_index] = rec_cnt;

always @(negedge pro_linevalid1 or negedge sys_rst_n) begin
    rec_cnt_ram[rec_cnt_index] = rec_cnt;
end

//reg [row_depth-1:0] rec_comp_index;

always @(*) begin
    rec_cnt_ram_revel <= rec_cnt_ram[rec_cnt_index]; 
    //������沨�γ���X̬��ԭ����ÿ��rec_cnt_index���º�rec_cnt_ram[rec_cnt_index]��ֵ�ǲ�ȷ����   
end

always @(posedge rd_clk or negedge sys_rst_n) begin
        rec_send_comp_revel <= rec_cnt_ram[rec_comp_index];
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_cnt <= 1'b1;  //��1��ԭ����send_cntҪ�����validһ��ʱ�����ڣ���ʼֵΪ1ʱ�պ�ƥ��
        rec_comp_index <= 1'b0;
        //sent_cs_cnt <= 1'b0;
    end
    else if(send_cnt == rec_cnt_ram[rec_comp_index]) begin
        send_cnt <= 1'b0;
        rec_comp_index <= rec_comp_index + 1'b1;
        //sent_cs_cnt <= sent_cs_cnt + 1'b1;
    end
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index)) //����������Ǳ�֤��Valid�ź�Ϊ�ͺ���Ȼ���Լ�����������
        send_cnt <= send_cnt + 1'b1;
    else
        send_cnt <= 1'b0;
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) 
        rec_comp_index <= 1'b0;
    else if((send_cnt == rec_cnt_ram[rec_comp_index]) && ((valid == 1'b1) || (rec_cnt_index != rec_comp_index))) 
        rec_comp_index <= rec_comp_index + 1'b1;
    else
        rec_comp_index <= rec_comp_index;
end

/*
//����һ�������������������ݴﵽ�������ݺ��������
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        send_cs_cnt <= 1'b0;
    else
        send_cs_cnt <= rec_cnt_ram[rec_comp_index];
end*/

/*
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        rec_comp_index <= 1'b0;
    end
    else if(send_cnt == 1'b0) begin
        rec_comp_index <= rec_comp_index + 1'b1;
    end
    else
        rec_comp_index <= rec_comp_index;
end*/
/*
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set_pre <= 1'b1;
    else if(send_cnt == rec_cnt_ram[rec_comp_index])
        cs_set_pre <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_set_pre <= 1'b0;
    else
        cs_set_pre <= 1'b1;
end*/

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set_pre <= 1'b1;
    else if(send_cnt == rec_cnt_ram[rec_comp_index])
        cs_set_pre <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_set_pre <= 1'b0;
    else
        cs_set_pre <= 1'b1;
end

/*reg     cs_set_pre1;

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set_pre1 <= 1'b1;
    else
        cs_set_pre1 <= cs_set_pre;
end*/
/*
//��cs_set1ͬ����rd_clk��ʱ����
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set1 <= 1'b1;
    else
        cs_set1 <= cs_set_pre;
end*/

always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_set <= 1'b1;
    else
        cs_set <= cs_set_pre;
end

always @(negedge cs_set_pre or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_cnt <= 1'b0;
    else if(cs_cnt == 4'd8)
        cs_cnt <= 1'b0;
    else
        cs_cnt <= cs_cnt + 1'b1;
end

always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_intr <= 1'b1;
    else if(cs_cnt == 4'd0)
        cs_intr <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_intr <= 1'b0;
    else
        cs_intr <= cs_intr;
end

//����1us��ʱ���ź�
always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us_cnt <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us_cnt <= 1'b0;
    else
        clk_us_cnt <= clk_us_cnt + 1'b1;
end

always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us <= ~clk_us;
    else
        clk_us <= clk_us;
end


/*
//rd_sck��sck�˷�Ƶ���ʱ�ӣ�ָʾfifo�Ķ�������
always@(posedge sck or negedge sys_rst_n)  //��sck�����ز���rd_clk
    if(sys_rst_n == 1'b0) 
        delaied_rd_clk <=  1'b0;
    else 
        delaied_rd_clk <=  rd_clk;*/

/*
//state:����ʽ״̬����һ�Σ�״̬��ת
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  FOT;    //frame_valid��ʹ��ʱstate����FOT״̬
    else
    case(state)
        FOT:   
                if(frame_vaild == 1'b1)  
                    state <= WR_EN_FRAME;   //frame_validʹ�ܺ�state����WR_EN_FRAME״̬�ȴ�line_validʹ��
                else
                    state <= FOT;   //frame_valid��ʹ��ʱstate����FOT״̬

        WR_EN_FRAME:  
                if(line_vaild == 1'b1)  
                    state <= WR_EN_LINE;   //frame_validʹ����line_validʹ��ʱ�����ж�ȡ״̬����ʼ���ж�ȡ����
                else if(frame_vaild == 1'b0)
                    state <= FOT;     //��WR_EN_FRAME״̬��frame_validʧ�ܺ���ת��FOT״̬
                else
                    state <= ROT;   //frame_validʹ�ܵ�line_validδʹ��ʱ����ROT״̬�ȴ�line_validʹ��

        ROT:    if(line_vaild == 1'b1)
                    state <= WR_EN_LINE; //frame_validʹ����line_validʹ��ʱ�����ж�ȡ״̬����ʼ���ж�ȡ����
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_validʧ�ܺ���ת��FOT״̬����WR_EN_LINE(frame_vaild == 1'b0)����
                                        //FOT����ͻ����Ϊ����WR_EN_LINE��ǰ����line_vaildʹ�ܣ���line_vaildʧ��Ҳ�ܽ���ROT
                else
                    state <= ROT;   //ROT��default״̬
                    
        WR_EN_LINE:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_validʹ�ܵ�line_validʧ��ʱ����ROT�п���״̬
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_validʧ��ʱֱ�ӻص�FOT״̬
                else
                    state <= WR_EN_LINE;    //���ֶ�ȡ״̬
                    
        default:    state   <=  FOT;
    endcase*/

//state:����ʽ״̬����һ�Σ�״̬��ת
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        state   <=  FOT;    //frame_valid��ʹ��ʱstate����FOT״̬
    else
    case(state)
        FOT:   
                if((frame_vaild == 1'b1) && (line_vaild == 1'b1))  
                    state <= WR_EN;   
                else if((frame_vaild == 1'b1) && (line_vaild == 1'b0))  
                    state <= ROT; 
                else
                    state <= FOT;  

        ROT:    if(line_vaild == 1'b1)
                    state <= WR_EN; 
                else if(frame_vaild == 1'b0)
                    state <= FOT;       
                else
                    state <= ROT;   //ROT��default״̬
                    
        WR_EN:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_validʹ�ܵ�line_validʧ��ʱ����ROT�п���״̬
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_validʧ��ʱֱ�ӻص�FOT״̬
                else
                    state <= WR_EN;    //���ֶ�ȡ״̬
                    
        default:    state   <=  FOT;
    endcase
end

//�����������Ϊ�����state��ʱ���������ܺ�state����,ͬʱ�ճ�����һ��ʱ��Ҳ���Ը�CS�ź��������߱�־һ���������
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid1 <= 1'b0;
    else
        pro_linevalid1 <= line_vaild;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid2 <= 1'b0;
    else
        pro_linevalid2 <= pro_linevalid1;
end

//����state����start_trans�ź�
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_trans <= 1'b0;
    //else if((state == WR_EN) && (cs_n == 1'b0))
    //    start_trans <= 1'b1;
    else if((pro_linevalid2 != line_vaild) && (state == ROT))
        start_trans <= 1'b1;
    else
        start_trans <= start_trans;
end

/*
//����state����start_trans�ź�,����ź��ڵ�һ��line_valid�ź�����ʱ��(��ʼ������֮��)��ֱ�����߿�ʼ����
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_trans <= 1'b0;
    else if(line_vaild == 1'b1)
        start_trans <= 1'b1;
    else
        start_trans <= start_trans;
end*/
endmodule



    //output   reg     [7:0]  delay_cnt,
    //output   reg            delay_flag,
    //output   wire            package_ready,      //FIFO�����ı�־���ݰ�׼���õ��ź�
    //output   reg            finish_trans,  //����FIFO�ı�־һ�����ݴ���������ź�
    //output   reg            start_intr,
    //output   reg     [9:0]  package_cnt,
    //output   reg     [9:0]  finish_cnt,
    //output   reg     cs_pos_edge,
    //output   reg     cs_pre_edge,
    //output   reg     cs_n_posedge,
    //output   reg     cs_n_negedge,
    //output   wire    cs_p,
    //output   reg     pos_delay_start,
    //output   reg     first_pre_delay_start,
    //output   reg     pos_start_intr,
    //output   reg     start_intr_posedge


/*--------------------------------------------------------------------------------------------------*/
/*
//����cs�ź�
//����Ĵ������м����ƣ�����ʵ��ÿ�в�ͬ���ȵĴ���
reg [row_depth-1:0] rec_cnt_ram [colume_width:0];
//reg [row_depth-1:0] rec_cnt_index;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        rec_cnt_index <= 1'b0;
    else if((pro_linevalid2 != pro_linevalid1) && (state == ROT))
        rec_cnt_index <= rec_cnt_index + 1'b1;
    else
        rec_cnt_index <= rec_cnt_index;
end

//assign rec_cnt_ram[rec_cnt_index] = rec_cnt;

always @(negedge pro_linevalid1 or negedge sys_rst_n) begin
    rec_cnt_ram[rec_cnt_index] = rec_cnt;
end

//reg [row_depth-1:0] rec_comp_index;

always @(*) begin
    rec_cnt_ram_revel <= rec_cnt_ram[rec_cnt_index]; 
    //������沨�γ���X̬��ԭ����ÿ��rec_cnt_index���º�rec_cnt_ram[rec_cnt_index]��ֵ�ǲ�ȷ����   
end

always @(posedge rd_clk or negedge sys_rst_n) begin
        rec_send_comp_revel <= rec_cnt_ram[rec_comp_index];
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_cnt <= 1'b1;  //��1��ԭ����send_cntҪ�����validһ��ʱ�����ڣ���ʼֵΪ1ʱ�պ�ƥ��
        rec_comp_index <= 1'b0;
        //sent_cs_cnt <= 1'b0;
    end
    else if(send_cnt == rec_cnt_ram[rec_comp_index]) begin
        send_cnt <= 1'b0;
        rec_comp_index <= rec_comp_index + 1'b1;
        //sent_cs_cnt <= sent_cs_cnt + 1'b1;
    end
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index)) //����������Ǳ�֤��Valid�ź�Ϊ�ͺ���Ȼ���Լ�����������
        send_cnt <= send_cnt + 1'b1;
    else
        send_cnt <= 1'b0;
end

always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) 
        rec_comp_index <= 1'b0;
    else if((send_cnt == rec_cnt_ram[rec_comp_index]) && ((valid == 1'b1) || (rec_cnt_index != rec_comp_index))) 
        rec_comp_index <= rec_comp_index + 1'b1;
    else
        rec_comp_index <= rec_comp_index;
end

//���ǲ����д����־�źŵģ���MISOʱ���һ��SCK���ڣ�
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_line_set_pre <= 1'b1;
    else if(send_cnt == rec_cnt_ram[rec_comp_index])
        cs_line_set_pre <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_line_set_pre <= 1'b0;
    else
        cs_line_set_pre <= 1'b1;
end

//cs_line_set_pre���������MISOʱ��
always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_line_set <= 1'b1;
    else
        cs_line_set <= cs_line_set_pre;
end

//��������cs_multi_line_intr�źŵļ�������8��cs_line_set������Ϊһ����������һ��cs_multi_line_intr�ź�
always @(negedge cs_line_set_pre or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_line_cnt <= 1'b0;
    else if(cs_line_cnt == 4'd8)
        cs_line_cnt <= 1'b0;
    else
        cs_line_cnt <= cs_line_cnt + 1'b1;
end

//����źű�־�Ű�λ���ݴ�����ɣ���MISO�ź���һ��rd_clk���ڣ�
always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_multi_line_intr <= 1'b1;
    else if(cs_line_cnt == 4'd0)
        cs_multi_line_intr <= 1'b1;
    else if((valid == 1'b1) || (rec_cnt_index != rec_comp_index))
        cs_multi_line_intr <= 1'b0;
    else
        cs_multi_line_intr <= cs_multi_line_intr;
end

//����ź���cs_multi_line_intr��rd_clk�´�һ�ĵõ��ģ��������validʱ��İ�λ���ݴ����־�ź�
reg cs_out_pre;
always @(posedge rd_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_out_pre <= 1'b1;
    else
        cs_out_pre <= cs_multi_line_intr;
end

//cs_out��multi_line_flag��sck�´�һ�ĵõ���
always @(posedge sck or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_out <= 1'b1;
    else
        cs_out <= cs_out_pre;
end

//�ڰ�ͷ/β����̶�ʱ��
//reg     [5:0]   delay_cnt;
//�ڰ�ͷ��ӵ���ʱͨ���ı������������ֵ�ı�
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        delay_cnt <= 1'b0;
    else if(delay_cnt == 8'd100)
        delay_cnt <= 1'b0;
    else 
        delay_cnt <= delay_cnt + 1'b1;
end

//reg     delay_flag;
always @(posedge sys_clk or negedge sys_rst_n) begin     //�������ʱ��ֻ����sck�²�����
    if(sys_rst_n == 1'b0)
        delay_flag <= 1'b0;
    else if(cs_out == 1'b1)
        delay_flag <= 1'b0;         //Ϊ��֤ÿ�ζ�׼ȷ��cs_outǰ����ʱ�ӣ���cs_outΪ1ʱ����flag�ͼ�����
    else if(delay_cnt == 8'd100)
        delay_flag <= 1'b1;
    else
        delay_flag <= delay_flag;
end

//����1us��ʱ���ź�
always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us_cnt <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us_cnt <= 1'b0;
    else
        clk_us_cnt <= clk_us_cnt + 1'b1;
end

always @(negedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        clk_us <= 1'b0;
    else if(clk_us_cnt == 6'd50)
        clk_us <= ~clk_us;
    else
        clk_us <= clk_us;
end

//�����������Ϊ�����state��ʱ���������ܺ�state����,ͬʱ�ճ�����һ��ʱ��Ҳ���Ը�CS�ź��������߱�־һ���������
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid1 <= 1'b0;
    else
        pro_linevalid1 <= line_vaild;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pro_linevalid2 <= 1'b0;
    else
        pro_linevalid2 <= pro_linevalid1;
end

//����state����start_trans�ź�
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_trans <= 1'b0;
    //else if((state == WR_EN) && (cs_n == 1'b0))
    //    start_trans <= 1'b1;
    else if((pro_linevalid2 != line_vaild) && (state == ROT))
        start_trans <= 1'b1;
    else
        start_trans <= start_trans;
end

*/