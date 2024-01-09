`timescale  1ns/1ns

module  Sys#(
    parameter   data_width = 8,
    parameter   data_depth = 11552,
    parameter   addr_width = 14,
    parameter   package_size = 11552
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

    input   wire            monitor     ,   //״̬���������ź�

    output  wire    [7:0]   data_out    ,

    output  wire    [7:0]   data_in     ,
    input   wire            cs_n        ,
    input   wire            sck         ,   //����ʱ��
    output  wire            miso        ,   //���������������

    output  wire            status_led  ,   //״ָ̬ʾ�ƣ�package_ready����
    output  wire            monitor_led ,   //�ع�LED����monitor����

    output  wire            intr_out    ,

    output   wire           data_out0    ,
    output   wire           data_out1    ,
    output   wire           data_out2    ,
    output   wire           data_out3    ,
    output   wire           data_out4    ,
    output   wire           data_out5    ,
    output   wire           data_out6    ,
    output   wire           data_out7    ,

    output   wire           clk_out_out    ,  //����ͬ���ź�
    output   wire           frame_vaild_out,  //֡ͬ���ź�
    output   wire           line_vaild_out ,   //��ͬ���ź� 

    output   wire           cs_n_out   ,      //Ƭѡ�ź�
    output   wire           wr_en      ,
    output   wire           package_ready,
    output   wire           valid       ,
    output   wire           rd_clk      ,
    output   wire           rd_en       ,
    output   wire           rd_out      ,
    output   wire           daq_clk     ,
    output   wire [addr_width-1:0]  rd_addr1 ,
    output   wire [addr_width-1:0]  wr_addr1 ,
    output   wire [addr_width-1:0]  wr_addr2 ,
    output   wire [addr_width-1:0]  rd_addr2 ,
    output   wire            rd_en1     ,
    output   wire            full1  ,
    output   wire            full2  ,
    output   wire            wr_en1 ,
    output   wire            wr_en2 ,
    output   wire            ram_wr_sel,
    output   wire            ram1_rd_sel,
    output   wire            ram2_rd_sel,
    input    wire            data_gen_rst
    
);

wire    [2:0]   cnt_bit      ;   //���ؼ�����
wire    [2:0]   state        ;
wire            empty        ;
wire            empty1       ;
wire            empty2       ;
wire            rd_en2       ;
wire            rd_sel       ;
wire            valid1       ;
wire            valid2       ;
wire            emp_sel      ;
wire [data_width-1:0]  dout1 ;
wire [data_width-1:0]  dout2 ;  

DATA_INC_GEN#(
    .CNT_CLK_2MHZ_MAX (19)   ,
    .CNT_CLK_4MHZ_MAX (9)    ,
    .CNT_MAX          (12160)
)DATA_INC_GEN_INST
(
    .sys_clk     (sys_clk    ),
    .rst_n       (sys_rst_n  ),
    .data_out0   (data_out0  ) ,
    .data_out1   (data_out1  ) ,
    .data_out2   (data_out2  ) ,
    .data_out3   (data_out3  ) ,
    .data_out4   (data_out4  ) ,
    .data_out5   (data_out5  ) ,
    .data_out6   (data_out6  ) ,
    .data_out7   (data_out7  ) ,
    .clk_out     (clk_out_out) ,
    .frame_vaild (frame_vaild_out) ,
    .line_vaild  (line_vaild_out )  
);
//parameter define
parameter   FOT        =   3'b001 ,   //֡����״̬
            WR_EN      =   3'b010 ,   //��ʹ��״̬
            ROT        =   3'b100 ;   //�п���״̬

DAQ_sync DAQ_sync_inst
(
    .sys_clk     ( sys_clk   ),   //ϵͳʱ�ӣ�Ƶ��50MHz
    .sys_rst_n   ( data_gen_rst ),   //��λ�ź�,�͵�ƽ��Ч
    .data_in0    ( data_in0  ),
    .data_in1    ( data_in1  ),
    .data_in2    ( data_in2  ),
    .data_in3    ( data_in3  ),
    .data_in4    ( data_in4  ),
    .data_in5    ( data_in5  ),
    .data_in6    ( data_in6  ),
    .data_in7    ( data_in7  ),
 
    .clk_out     ( clk_out   ),  //����ͬ���ź�
    .frame_vaild (frame_vaild),  //֡ͬ���ź�
    .line_vaild  (line_vaild ),  //��ͬ���ź�

    .state       (  state    ),


    .data_in     (  data_in  ),
    .daq_clk     (  daq_clk  )
);

SPI_transfer SPI_transfer_inst
(
    .sck         (  sck      ),   //��������Ĵ���ʱ��
    .sys_rst_n   ( sys_rst_n ),   //��λ�ź�,�͵�ƽ��Ч
    .data_in     (  data_out ),
    .valid       (  valid    ),
    .cs_n        (  cs_n     ),
    .miso        (  miso     ),   //���������������
    .cnt_bit     (  cnt_bit  )    //���ؼ�����

);

ring_fifo#(
    .data_width    ( data_width  ),   //���ݿ��
    .data_depth    ( data_depth  ),   //FIFO���
    .addr_width    ( addr_width  ),   //��ַ���
    .package_size  (package_size )    //�ܰ���������Ӧ����38912
)ring_fifo_inst
(
    .sys_clk       (   sys_clk   ),
    .rst_n         (  sys_rst_n  ),       //�첽��λ
    .wr_clk        (   daq_clk   ),       //����дʱ��
    .wr_en         (    wr_en    ),       //����ʹ��
    .din           (   data_in   ),       //��������
    .rd_clk        (    rd_clk   ),       //���ݶ�ʱ��
    .rd_en         (    rd_en    ),       //���ʹ��
    .intr_out      (   intr_out  ),
    
    .valid         (    valid    ),       //������Ч��־(��FIFO�����ݷ������ظ��������һ��bit����ʱֻ��Ҫ��valid�жϼ���)
    .dout          (   data_out  ),       //�������
    .package_ready (package_ready),       //FIFO�д���һ�����ݱ�־
    .rd_out        (    rd_out   ),       //���ձ�־�ź�

    .empty         (   empty     ),
    .empty1        (   empty1    ),
    .empty2        (   empty2    ),
    .full1         (   full1     ),
    .full2         (   full2     ),
    .wr_en1        (   wr_en1    ),
    .wr_en2        (   wr_en2    ),
    .rd_en1        (   rd_en1    ),
    .rd_en2        (   rd_en2    ),
    .rd_sel        (   rd_sel    ),
    .dout1         (   dout1     ),
    .dout2         (   dout2     ),
    .valid1        (   valid1    ),
    .valid2        (   valid2    ),
    .emp_sel       (  emp_sel    ),
    .wr_addr1      (  wr_addr1   ),
    .rd_addr1      (  rd_addr1   ),
    .wr_addr2      (  wr_addr2   ),
    .rd_addr2      (  rd_addr2   ),
    .ram_wr_sel    ( ram_wr_sel  ),
    .ram1_rd_sel   ( ram1_rd_sel ),
    .ram2_rd_sel   ( ram2_rd_sel )
);

//���ݲɼ�״̬��
state_ctrl#(.FOT (FOT), .WR_EN (WR_EN), .ROT (ROT))
state_ctrl_inst(
    .clk         (  sys_clk  ),
    .rst_n       ( sys_rst_n ),
    .line_vaild  (line_vaild ),
    .frame_vaild (frame_vaild),

    .state       (  state    )
);

//FIFO��ʱ�Ӳ�����8λ���ݶ���һ��
sck2rd_clk sck2rd_clk_inst(.sck(sck), .sys_rst_n(sys_rst_n), .rd_clk(rd_clk));

//����дʹ���ź�wr_en
assign wr_en = line_vaild;

//FIFO���ź���ESP32������Ƭѡ�ź�ȡ��
assign rd_en = ~cs_n;   

assign intr_out = package_ready;

//��package_ready����5��daq_clk���ӳٵõ�ESP32�жϴ����ź�intr_out
//delayn#(.n(5)) delayn_inst(.clk(daq_clk), .rst_n(sys_rst_n), .in(package_ready), .out(intr_out));

//״ָ̬ʾ��
LEDctrl LEDctrl_status(.clk(sys_clk), .rst(sys_rst_n), .signal(package_ready), .led_ctrl(status_led));

//CMOS�˳��͹��Ŀ�ʼ�ع⣬�ع�LED
LEDctrl LEDctrl_monitor(.clk(sys_clk), .rst(sys_rst_n), .signal(monitor), .led_ctrl(monitor_led));

endmodule