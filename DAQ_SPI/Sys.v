`timescale  1ns/1ns

module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 300,
    parameter   addr_width = 14,
    parameter   package_size = 300 ,
    parameter   multiline_num = 8
)
(
    input   wire            sys_clk     ,   //ϵͳʱ�ӣ�Ƶ��50MHz
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч
/*    input   wire            data_in0    ,
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
*/
    //input   wire            start_intr   , //ESP32�����������ź�
    
    output  wire    [7:0]   data_out    ,
    output  wire            rd_empty    ,
    output  wire            wr_full     ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,   //Ƭѡ�ź�
    input   wire            sck         ,   //����ʱ��
    output  wire            miso        ,   //���������������
    output  wire    [2:0]   cnt_bit     ,   //���ؼ�����
    output  reg     [2:0]   state       ,
    output  wire            daq_clk     ,
    output  reg     [2:0]   sck_cnt     ,
    output  wire            valid       ,
    output  reg             rd_clk      ,
    output  wire            package_ready,
    output  wire            clk_out     ,
    output  wire            wr_en       ,
    output  wire            rd_en       ,

    output  wire            intr_out    

);

//parameter define
parameter   FOT           =   3'b001 ,   //֡����״̬
            WR_EN         =   3'b010 ,   //��ʹ��״̬
            ROT           =   3'b100 ;   //�п���״̬

wire            data_in0    ;
wire            data_in1    ;
wire            data_in2    ;
wire            data_in3    ;
wire            data_in4    ;
wire            data_in5    ;
wire            data_in6    ;
wire            data_in7    ;
//wire            clk_out     ;
wire            frame_vaild ;
wire            line_vaild  ;

DATA_GEN#(
    .CNT20_MAX  ( 4  ),
    .CNT10_MAX  ( 9  ),
    .CNT5_MAX   ( 19 ),
    .LINE_MAX   (100 ),
    .FRAME_MAX  (2000)
) DATA_GEN_inst
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
    .clk_out     (clk_out    ),
    .frame_vaild (frame_vaild),
    .line_vaild  (line_vaild )
);

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
    .daq_clk     (daq_clk    )
);

SPI_transfer SPI_transfer_inst
(
    .sck         (sck        ),   //��������Ĵ���ʱ��
    .sys_rst_n   (sys_rst_n  ),   //��λ�ź�,�͵�ƽ��Ч
    .data_in     (data_out   ),
    .valid       (valid      ),
    .cs_n        (cs_n       ),
    .miso        (miso       ),   //���������������
    .cnt_bit     (cnt_bit    )    //���ؼ�����

);

ring_fifo#(
    .data_width    ( data_width  ),   //���ݿ��
    .data_depth    ( data_depth  ),   //FIFO���
    .addr_width    ( addr_width  ),   //��ַ���
    .package_size  (package_size )    //�ܰ���������Ӧ����38912
)ring_fifo_inst
(
    .rst_n         (  sys_rst_n  ),       //�첽��λ
    .wr_clk        (   daq_clk   ),       //����дʱ��
    .wr_en         (    wr_en    ),       //����ʹ��
    .din           (   data_in   ),       //��������
    .rd_clk        (    rd_clk   ),       //���ݶ�ʱ��
    .rd_en         (    rd_en    ),       //���ʹ��
    
    .valid         (    valid    ),       //������Ч��־(��FIFO�����ݷ������ظ��������һ��bit����ʱֻ��Ҫ��valid�жϼ���)
    .dout          (   data_out  ),       //�������
    .package_ready (package_ready),       //FIFO�д���һ�����ݱ�־
    .rd_out        (    rd_out   )        //���ձ�־�ź�
);

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

//����дʹ���ź�wr_en
assign wr_en = line_vaild;

//��package_ready��������daq_clk���ӳٵõ�ESP32�жϴ����ź�intr_out
wire   intr_out_pre;
assign intr_out_pre = package_ready;

delayn#(.n(3)) delayn_inst(.clk(daq_clk), .rst_n(rst_n), .in(intr_out_pre), .out(intr_out));

assign rd_en = ~cs_n;   //FIFO���ź���ESP32������Ƭѡ�ź�ȡ��

endmodule