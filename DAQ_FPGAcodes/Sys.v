`timescale  1ns/1ns

module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 600,
    parameter   addr_width = 12,
    parameter   row_depth  = 304,
    parameter   colume_width = 304,
    parameter   row_num = 8,
    parameter   package_size = 38192
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

    //input   wire            start_intr   , //ESP32�����������ź�
    
    output  wire    [7:0]   data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,   //Ƭѡ�ź�
    input   wire            sck         ,   //����ʱ��
    output  reg             cs_line_set      ,   //���������ͬ��ʹ���ź�
    output  wire            miso        ,   //���������������
    output  wire    [2:0]   cnt_bit     ,    //���ؼ�����
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  wire            start_trans ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    //output  reg            pro_linevalid1,
    //output  reg            pro_linevalid2,
    output   wire  [addr_width-1:0]  wr_addr      ,
    output   wire  [addr_width-1:0]  rd_addr      ,
    //output   reg   [9:0]   send_cnt,
    //output   reg      cs_line_set_pre,
    //output   reg   [9:0] rec_cnt_index,
    //output   reg   [9:0] rec_comp_index,
    //output   reg   [9:0] rec_cnt_ram_revel,
    //output   reg   [9:0] rec_send_comp_revel,
    //output   wire  [15:0]   sent_cnt,
    //output   reg   [3:0]   cs_line_cnt,
    //output   reg          cs_multi_line_intr,
    //output   reg         clk_us,
    //output   reg [5:0]   clk_us_cnt,  
    //output   wire   [3:0]  duty_cnt,
    //output   wire     state_flag,
    //output   wire     multi_line_flag,
    //output   reg      cs_out,
    //output   reg     [7:0]  pre_delay_cnt,  //����������ʱ
    //output   reg            pre_delay_flag,
    //output   reg     [7:0]  pos_delay_cnt,
    //output   reg            pos_delay_flag,
    output   reg            intr_out

);

//parameter define
parameter   FOT           =   3'b001 ,   //֡����״̬
            WR_EN         =   3'b010 ,   //��ʹ��״̬
            ROT           =   3'b100 ;   //�п���״̬

reg     [7:0]  pre_delay_cnt;  //����������ʱ
reg            pre_delay_flag;
reg     [7:0]  pos_delay_cnt;
reg            pos_delay_flag;
reg     [7:0]  delay_cnt;
reg            delay_flag;
wire            package_ready;  //FIFO�����ı�־���ݰ�׼���õ��ź�
reg            finish_trans;    //����FIFO�ı�־һ�����ݴ���������ź�
reg            start_intr;
reg     [9:0]  package_cnt;
reg     [9:0]  finish_cnt;
reg     cs_pos_edge;
reg     cs_pre_edge;
reg     cs_n_posedge;
reg     cs_n_negedge;
wire    cs_p;
reg     pos_delay_start;
reg     first_pre_delay_start;
reg     pos_start_intr;
reg     start_intr_posedge;

//assign multi_line_flag = state_flag | cs_multi_line_intr;

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
    //.cs_set      (cs_line_set_pre ),
    .cs_n        (cs_n       ),

    .miso        (miso       ),   //���������������
    .cnt_bit     (cnt_bit    ),   //���ؼ�����
    .sent_cnt    (sent_cnt   )
    //.duty_cnt    (duty_cnt   ),
    //.state_flag  (state_flag )
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
    .rd_en  (start_trans),  //start_trans�ź�Ӧ����ESP32������CS�ź�ȡ��
    .valid  (valid     ),
    .dout   (data_out  ),
    .spi_sck(sck       ),
    .cs_n   (cs_n      ),
    .finish_trans (finish_trans),
    .empty  (rd_empty  ),
    .full   (wr_full   ),
    .package_ready (package_ready ),
    .wr_addr       (wr_addr       ),
    .rd_addr       (rd_addr       )
    );

assign start_trans = ~ cs_n;    //��ʼ�����ź���CS�ź�ȡ��
assign cs_p = ~ cs_n;   

//state:����ʽ״̬��
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

//reg     start_intr;     //����ź����Լ���ģ�Ŀ��������SPI���䣨�Ⲣ�������DAQģ��Ĺ�������Ҳ��Ӱ��FIFO�Ķ�ȡ��
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_intr <= 1'b0;
    else if(rd_empty != 1'b1)
        start_intr <= 1'b1;         //CS�ź�Ӧ������start_intr����ʱ100��clk������֮��
    else 
        start_intr <= start_intr;   
    //��DAQģ�鿪ʼ�ɼ����ݺ�ʼ�ж�ʹ���ź��������ΪESP32�˻���Ҫ40~60us��ʱ������ʼ��SPI���ߣ�������ʱ������Ӱ�����������߼�
end

/*�����ж�ʹ���źţ�û���м����ƣ�*/
/*----------------------------------CS�źű��ؼ��---------------------------------------*/  
//������ؼ���ִ����������ϵͳ��ʼ�������������һ�����ؼ�����壬��˻��ɼ��csȡ������ź���
//cs�źŴ��ĵõ�cs_pos_edge
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_pos_edge <= 1'b0;
    else
        cs_pos_edge <= cs_p;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_pre_edge <= 1'b0;
    else
        cs_pre_edge <= cs_n;
end

//���cs������
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_n_posedge <= 1'b0;
    else if((cs_pos_edge == 1'b1) && (cs_p == 1'b0))  //���������
        cs_n_posedge <= 1'b1;
    else
        cs_n_posedge <= 1'b0;
end

//���cs�½���
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cs_n_negedge <= 1'b0;
    else if((cs_pre_edge == 1'b1) && (cs_n == 1'b0))  //����½���
        cs_n_negedge <= 1'b1;
    else
        cs_n_negedge <= 1'b0;
end

//���start_intr��������
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pos_start_intr <= 1'b0;
    else
        pos_start_intr <= start_intr;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        start_intr_posedge <= 1'b0;
    else if((pos_start_intr == 1'b0) && (start_intr == 1'b1))  //���������
        start_intr_posedge <= 1'b1;
    else
        start_intr_posedge <= 1'b0;
end

/*------------------------------����pre_delay_flag�ź�--------------------------------*/
//����һ��pre_delayʹ���źţ�����Ϊ���ڵ�һ�����ڴ���ʱ����pre_delay_flag�ģ�����ڵ�һ��cs�½��ص���ʱ������
always @(posedge sys_clk or negedge sys_rst_n) begin    
    if(sys_rst_n == 1'b0)
        first_pre_delay_start <= 1'b0;
    else if((start_intr ==1'b1) && (cs_n == 1'b1))  //��һ�����������,��ʱCS�ź��Ѿ�����������ͨ��CS�źŽ��п���
        first_pre_delay_start <= start_intr;         //Ϊ��֤ÿ�ζ�׼ȷ��cs_outǰ����ʱ�ӣ���cs_outΪ1ʱ����flag�ͼ�����
    else if(cs_n == 1'b0)
        first_pre_delay_start <= 1'b0;
    else
        first_pre_delay_start <= first_pre_delay_start;
end

//���������ݴ���ǰ����ʱ
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pre_delay_cnt <= 1'b0;
    //else if((cs_n == 1'b1) && (start_intr == 1'b0))
    else if(cs_n_posedge == 1'b1)
        pre_delay_cnt <= 1'b0;
    else if((pre_delay_flag == 1'b0) && (pos_delay_flag == 1'b1) && (package_cnt != finish_cnt))// && (package_ready == 1'b1) //����CS�ź��Ǹ���pre_delay_flag�����ģ�������ﲻ����CS�ź�����־
        pre_delay_cnt <= pre_delay_cnt + 1'b1;
    //else if(first_pre_delay_start == 1'b1)
    //    pre_delay_cnt <=  pre_delay_cnt;    //���������ֵ�󱣳֣�ֱ��cs_n���ߺ�����
end

//����źź�ʱ�����ʱ���²���Ҫ���CS���ǣ���ΪCS�ź�����delay_flag����������
always @(posedge sys_clk or negedge sys_rst_n) begin    
    if(sys_rst_n == 1'b0)
        pre_delay_flag <= 1'b0;
    else if(cs_n_posedge ==1'b1)  //��һ�����������,��ʱCS�ź��Ѿ�����������ͨ��CS�źŽ��п���
        pre_delay_flag <= 1'b0;         //Ϊ��֤ÿ�ζ�׼ȷ��cs_outǰ����ʱ�ӣ���cs_outΪ1ʱ����flag�ͼ�����
    else if(pre_delay_cnt == 8'd100)
        pre_delay_flag <= 1'b1;
    //else if(first_pre_delay_start == 1'b1)
    //    pre_delay_flag <= 1'b1;
    else if(start_intr_posedge == 1'b1)
        pre_delay_flag <= 1'b1;
    else
        pre_delay_flag <= pre_delay_flag;
end

/*-----------------------------����pos_delay_flag�ź�----------------------------------*/
//����������ʱ��ʼ�ź�
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pos_delay_start <= 1'b0;
    else if(cs_n_posedge == 1'b1)
        pos_delay_start <= 1'b1;
    else if(cs_n_negedge == 1'b1)
        pos_delay_start <= 1'b0;
    else
        pos_delay_start <= pos_delay_start;
end

//�������ô�����������ʱ
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pos_delay_cnt <= 1'b0;
    //else if(cs_n == 1'b1)
    else if(pos_delay_start == 1'b1)
        pos_delay_cnt <= pos_delay_cnt + 1'b1;
    //else if(cs_n == 1'b0)   //����CS�ź��Ѿ������ˣ����Ը���CS�źŽ�������
    else if(pos_delay_start == 1'b0)
        pos_delay_cnt <= 1'b0;
    else if(pos_delay_cnt == 8'd100)
        pos_delay_cnt <=  pos_delay_cnt;    //���������ֵ�󱣳֣�ֱ��pos_delay_start���ͺ�����
end

//����źź�ʱ�����ʱ���²���Ҫ���CS���ǣ���ΪCS�ź�����delay_flag����������
always @(posedge sys_clk or negedge sys_rst_n) begin    
    if(sys_rst_n == 1'b0)
        pos_delay_flag <= 1'b0;
    //else if(cs_n == 1'b0)  //��һ�����������,��ʱCS�ź��Ѿ�����������ͨ��CS�źŽ��п���
    else if(pos_delay_start == 1'b0)
        pos_delay_flag <= 1'b0;         //Ϊ��֤ÿ�ζ�׼ȷ��cs_outǰ����ʱ�ӣ���cs_outΪ1ʱ����flag�ͼ�����
    else if((pos_delay_cnt == 8'd100) && (pos_delay_start == 1'b1))
        pos_delay_flag <= 1'b1;
    else
        pos_delay_flag <= pos_delay_flag;
end

//�����ж��ź�
always @(posedge sys_clk or negedge sys_rst_n) begin    //����pre_delay_flag��pos_delay_flag��ʱ��
    if(sys_rst_n == 1'b0)
        intr_out <= 1'b0;
    else if(pre_delay_flag == 1'b1)  
        intr_out <= 1'b1;        
    else if(pos_delay_flag == 1'b1)
        intr_out <= 1'b0;
    else
        intr_out <= intr_out;
end

//һ�����������־�ź�
always @(posedge sys_clk or negedge sys_rst_n) begin    //����pre_delay_flag��pos_delay_flag��ʱ��
    if(sys_rst_n == 1'b0)
        finish_trans <= 1'b0;     
    //else if(pos_delay_flag == 1'b1)
    else if(cs_n_posedge == 1'b1)       //����д���Ǹ���cs�ź����ˣ�����û��Ӱ��
        finish_trans <= 1'b1;       //һ�����ݴ��������־�ź�
    else 
        finish_trans <= 1'b0;
end

//package�����źţ���־��ǰFIFO���ж��ٸ�FIFO�ȴ����ͣ�ʵ�������һ����
always @(posedge sys_clk or negedge sys_rst_n) begin   
    if(sys_rst_n == 1'b0)
        package_cnt <= 1'b0;     
    else if(package_ready == 1'b1)
        package_cnt <= package_cnt + 1'b1;       //ÿ��package_ready�źŴ�����FIFO������һ�����ݣ��͸���������һ
    else 
        package_cnt <= package_cnt;
end

//finished package�����źţ���־��ǰ�Ѿ��ж��ٸ�package�Ѿ���������
always @(posedge sys_clk or negedge sys_rst_n) begin  
    if(sys_rst_n == 1'b0)
        finish_cnt <= 1'b0;     
    else if(finish_trans == 1'b1)
        finish_cnt <= finish_cnt + 1'b1;       //ÿ��finish_trans�źŴ�������ʾһ�������Ѿ������꣬���Ǹ���������һ
    else 
        finish_cnt <= finish_cnt;
end

assign start_trans = ~ cs_n;


endmodule