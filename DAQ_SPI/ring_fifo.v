module ring_fifo#(
    parameter   data_width = 8 ,     //���ݿ��
    parameter   data_depth = 4864,    //FIFO���
    parameter   addr_width = 14,    //��ַ���
    parameter   package_size = 4864   //�ܰ���������Ӧ����38912
)
(
    input   wire                    sys_clk,
    input   wire                    rst_n  ,       //�첽��λ
    input   wire                    wr_clk ,       //����дʱ��
    input   wire                    wr_en  ,       //����ʹ��
    input   wire  [data_width-1:0]  din    ,       //��������
    input   wire                    rd_clk ,       //���ݶ�ʱ��
    input   wire                    rd_en  ,       //���ʹ��
    input   wire                    intr_out,

    output   wire                   valid  ,       //������Ч��־(��FIFO�����ݷ������ظ��������һ��bit����ʱֻ��Ҫ��valid�жϼ���)
    output   wire [data_width-1:0]  dout   ,       //�������
    output   wire                   package_ready, //FIFO�д���һ�����ݱ�־
    output   wire                   rd_out        , //���ձ�־�ź�

    output   wire                   empty      ,
    output   wire                   empty1     ,
    output   wire                   empty2     ,
    output   wire                   full1      ,
    output   wire                   full2      ,
    output   wire                   wr_en1     ,
    output   wire                   wr_en2     ,
    output   wire                   rd_en1     ,
    output   wire                   rd_en2     ,
    output   reg                    rd_sel     ,
    output   wire [data_width-1:0]  dout1      ,
    output   wire [data_width-1:0]  dout2      ,  
    output   wire                   valid1     ,
    output   wire                   valid2     ,
    output   reg                    emp_sel    ,
    output   wire [addr_width-1:0]  wr_addr1   ,
    output   wire [addr_width-1:0]  rd_addr1   ,
    output   wire [addr_width-1:0]  wr_addr2   ,
    output   wire [addr_width-1:0]  rd_addr2   ,
    output   reg                    ram_wr_sel ,
    output   reg                    ram1_rd_sel,
    output   reg                    ram2_rd_sel

);
/*------------���rd_en�źű���------------*/
reg     rd_en_pre;
reg     rd_en_posedge;
always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        rd_en_pre <= 1'b0;
    else
        rd_en_pre <= rd_en;
end

always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        rd_en_posedge <= 1'b0;
    else if((rd_en_pre == 1'b0) && (rd_en == 1'b1))  //���������
        rd_en_posedge <= 1'b1;
    else
        rd_en_posedge <= 1'b0;
end

/*------------���wr_en�źű���------------*/
reg     wr_en_pre;
reg     wr_en_posedge;
always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        wr_en_pre <= 1'b0;
    else
        wr_en_pre <= rd_en;
end

always @(posedge wr_clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        wr_en_posedge <= 1'b0;
    else if((wr_en_pre == 1'b0) && (wr_en == 1'b1))  //���������
        wr_en_posedge <= 1'b1;
    else
        wr_en_posedge <= 1'b0;
end

/*------------ʵ������FIFO����д��------------*/
/*��дʱ��wr_clk�½���д������FIFO*/
//����RAM��ѡ���־�ź�
always@(posedge wr_clk or negedge rst_n)    //�ⲿ�ֵ�Ŀ���Ǳ�֤����д��һ��δд����FIFO
    if(!rst_n)          //��ʼ��
        ram_wr_sel <= 1'b0;
    else if(full1)   //FIFO1д����ʹ��FIFO2д�룬FIFO1��ʼ����
        ram_wr_sel <= 1'b1;    
    else if(full2)   //FIFO2д����ʹ��FIFO1д�룬FIFO2��ʼ����
        ram_wr_sel <= 1'b0;
    else 
        ram_wr_sel <= ram_wr_sel;

assign wr_en1 = (!ram_wr_sel) && (wr_en);
assign wr_en2 = (ram_wr_sel) && (wr_en);

/*�ڶ�ʱ��rd_clk�½����ȡ����FIFO*/
//���ڶ�ʱ��Ƶ��ԶԶ����дʱ�ӣ��������ݲ�����ֶ���������
//���ݶ����Ǹ���package_ready�ź�����־�ģ�package_ready����ͻᴥ��ESP32�жϣ�����CS�ź�
always@(posedge rd_clk or negedge rst_n)    //�ⲿ�ֵ�Ŀ���Ǳ�֤������ȡһ��δ�����FIFO
    if(!rst_n) begin          //��ʼ��
        ram1_rd_sel <= 1'b0;
        ram2_rd_sel <= 1'b0;
    end
    else if(full1) begin   //FIFO1д����ʹ��FIFO2д�룬FIFO1��ʼ����
        ram1_rd_sel <= 1'b1; 
        ram2_rd_sel <= 1'b0; 
    end   
    else if(full2) begin  //FIFO2д����ʹ��FIFO1д�룬FIFO2��ʼ����
        ram1_rd_sel <= 1'b0;
        ram2_rd_sel <= 1'b1;
    end
    else begin
        ram1_rd_sel <= ram1_rd_sel;
        ram2_rd_sel <= ram2_rd_sel;
    end

assign rd_en1 = (ram1_rd_sel) && (rd_en);
assign rd_en2 = (ram2_rd_sel) && (rd_en);

/*ָʾ����ź�dout��valid���ĸ�FIFO����*/
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n)         
        rd_sel <= 1'b0;
    else if(full1 == 1'b1)  
        rd_sel <= 1'b0;   //��������ź���FIFO1������    
    else if(full2 == 1'b1)   
        rd_sel <= 1'b1;   //��������ź���FIFO2������
    else                  
        rd_sel <= rd_sel;

/*��������ź�empty*/
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n)       //��ʼ��
        emp_sel <= 1'b0;
    else if(full1 == 1'b1)   //FIFO1д����ʹ��FIFO2д�룬FIFO1��ʼ����
        emp_sel <= 1'b0; 
    else if(full2 == 1'b1)   //FIFO2д����ʹ��FIFO1д�룬FIFO2��ʼ����
        emp_sel <= 1'b1;
    else   //������д��Ͷ�ȡ�����б���ʹ���ź�
        emp_sel <= emp_sel;

wire   rd_out1 ;
wire   rd_out2 ;

assign dout = (rd_sel) ? dout2 : dout1;
assign valid = (rd_sel) ? valid2 : valid1;
assign empty = (emp_sel) ? empty1 : empty2; 
assign rd_out = (rd_sel) ? rd_out2 : rd_out1;

/*����package_ready�ź�*/
assign package_ready = ((full1 == 1'b1) || (full2 == 1'b1));
/*always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n) 
        package_ready <= 1'b0;
    else if((full1 == 1'b1) || (full2 == 1'b1))
        package_ready <= 1'b1;
    else 
        package_ready <= 1'b0; //���߼���֤package_ready�źű���һ��wr_clk����
*/
/*���������ģ���У�����ʹ���ź���ȫ���ӵ�����ģ���ź���*/
async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //����Ӧ����38912
)async_ram_inst1
(
    .sys_clk      (  sys_clk  ),
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en1   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en1   ),
    .intr_out     ( intr_out  ),

    .valid        (  valid1   ),
    .dout         (  dout1    ),
    .empty        (  empty1   ),
    .full         (  full1    ),
    .wr_addr      ( wr_addr1  ),
    .rd_addr      ( rd_addr1  ),
    .rd_out       ( rd_out1   ) 
);


async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //����Ӧ����38912
)async_ram_inst2
(
    .sys_clk      (  sys_clk  ),
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en2   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en2   ),
    .intr_out     ( intr_out  ),

    .valid        (  valid2   ),
    .dout         (  dout2    ),
    .empty        (  empty2   ),
    .full         (  full2    ),
    .wr_addr      ( wr_addr2  ),
    .rd_addr      ( rd_addr2  ),
    .rd_out       ( rd_out2   )   
);

endmodule