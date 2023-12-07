module ring_fifo#(
    parameter   data_width = 8,
    parameter   data_depth = 30,
    parameter   addr_width = 14,
    parameter   package_size = 10  //����Ӧ����38912
)
(
    input   wire                    rst_n  ,
    input   wire                    wr_clk ,
    input   wire                    wr_en  ,
    input   wire  [data_width-1:0]  din    ,         
    input   wire                    rd_clk ,
    input   wire                    rd_en  ,

    output   wire                   valid  ,
    output   wire [data_width-1:0]  dout   ,
    output   reg                    package_ready, //ָʾ���������ݰ���׼����
    output   wire                   empty  ,
    output   wire                   empty1 ,
    output   wire                   full1  ,
    output   wire                   empty2 ,
    output   wire                   full2  ,
    output   reg                    wr_en1 ,
    output   reg                    wr_en2 ,
    output   reg                    rd_en1 ,
    output   reg                    rd_en2 ,
    output   wire                   rd_out ,
    output   reg                    rd_sel ,
    output   wire [data_width-1:0]  dout1  ,
    output   wire [data_width-1:0]  dout2  ,  
    output   wire                   valid1 ,
    output   wire                   valid2 ,
    output   reg                    emp_sel,
    output   wire [addr_width-1:0]   wr_addr1,
    output   wire [addr_width-1:0]   rd_addr1,
    output   wire [addr_width-1:0]   wr_addr2,
    output   wire [addr_width-1:0]   rd_addr2
);

//����FIFO��ѡ���ʹ���ź�
//reg    wr_en1;
//reg    wr_en2;
//reg    rd_en1;
//reg    rd_en2;

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

/*------------ʵ������FIFO����д��------------*/
/*��дʱ��wr_clk�½���д������FIFO*/
always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n) begin         //��ʼ��
        wr_en1 <= 1'b0;
        wr_en2 <= 1'b0;
    end
    else if(rd_en_posedge == 1'b1) begin    //rd_en�źŵ�����ʱ����FIFO1д�룬����FIFO2
        wr_en1 <= 1'b1;
        wr_en2 <= 1'b0;
    end
    else if(full1 == 1'b1) begin   //FIFO1д����ʹ��FIFO2д�룬FIFO1��ʼ����
        wr_en1 <= 1'b0;
        wr_en2 <= 1'b1;
    end       
    else if(full2 == 1'b1) begin   //FIFO2д����ʹ��FIFO1д�룬FIFO2��ʼ����
        wr_en1 <= 1'b1;
        wr_en2 <= 1'b0;
    end
    else begin   //������д��Ͷ�ȡ�����б���ʹ���ź�
        wr_en1 <= wr_en1;
        wr_en2 <= wr_en2;
    end

/*�ڶ�ʱ��rd_clk�½����ȡ����FIFO*/
always@(posedge rd_clk or negedge rst_n)    
    if(!rst_n) begin         //��ʼ��ʱ����FIFO�ж�û�����ݣ����ȫ����ʧ��
        rd_en1 <= 1'b0;
        rd_en2 <= 1'b0;
    end
    else if(full1 == 1'b1) begin   //FIFO1д����ʹ��FIFO2д�룬FIFO1��ʼ����
        rd_en1 <= 1'b1;
        rd_en2 <= 1'b0;
    end       
    else if(full2 == 1'b1) begin   //FIFO2д����ʹ��FIFO1д�룬FIFO2��ʼ����
        rd_en1 <= 1'b0;
        rd_en2 <= 1'b1;
    end
    else begin      //������д��Ͷ�ȡ�����б���ʹ���ź�
        rd_en1 <= rd_en1;
        rd_en2 <= rd_en2;
    end

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
always@(posedge wr_clk or negedge rst_n)    
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
always@(posedge wr_clk or negedge rst_n)    
    if(!rst_n) 
        package_ready <= 1'b0;
    else if((full1 == 1'b1) || (full2 == 1'b1))
        package_ready <= 1'b1;
    else 
        package_ready <= 1'b0; //���߼���֤package_ready�źű���һ��wr_clk����

/*���������ģ���У�����ʹ���ź���ȫ���ӵ�����ģ���ź���*/
async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //����Ӧ����38912
)async_ram_inst1
(
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en1   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en1   ),

    .valid        (  valid1   ),
    .dout         (  dout1    ),
    .empty        (  empty1   ),
    .full         (  full1    ),
    .wr_addr     (wr_addr1),
    .rd_addr     (rd_addr1),
    .rd_out      (rd_out1) 
);


async_ram#(
    .data_width   ( data_width   ),
    .data_depth   ( data_depth   ),
    .addr_width   ( addr_width   ),
    .package_size ( package_size )  //����Ӧ����38912
)async_ram_inst2
(
    .rst_n        (  rst_n    ),
    .wr_clk       (  wr_clk   ),
    .wr_en        (  wr_en2   ),
    .din          (  din      ),         
    .rd_clk       (  rd_clk   ),
    .rd_en        (  rd_en2   ),

    .valid        (  valid2   ),
    .dout         (  dout2    ),
    .empty        (  empty2   ),
    .full         (  full2    ),
    .wr_addr     (wr_addr2),
    .rd_addr     (rd_addr2),
    .rd_out      (rd_out1)   
);

endmodule