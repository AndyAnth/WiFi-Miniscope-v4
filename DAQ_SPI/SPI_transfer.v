`timescale  1ns/1ns

module  SPI_transfer
(
    input   wire            sck       ,   //��������Ĵ���ʱ��
    input   wire            sys_rst_n ,   //��λ�ź�,�͵�ƽ��Ч

    input   wire    [7:0]   data_in   ,
    input   wire            valid     ,
    input   wire            cs_n      ,

    output  reg             miso      ,   //���������������
    output  reg     [2:0]   cnt_bit       //���ؼ�����     

);

//cnt_bit:�ߵ�λ�Ե�������mosi���
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <= 3'd0;
    else if((valid == 1'b1) && (cs_n == 1'b0))      //ʱ���߼�������һ��
        cnt_bit <= cnt_bit + 1'b1;
    else if(cnt_bit == 3'd7)
        cnt_bit <= 3'd0;
    else
        cnt_bit <= cnt_bit;

//mosi:����ʽ״̬���ڶ��Σ��߼����
always@(posedge sck or negedge sys_rst_n)  //��posedgeд�룬����������negedge������
    if(sys_rst_n == 1'b0)
        miso <= 1'b0;
    else if((valid == 1'b1) && (cs_n == 1'b0))
        miso <= data_in[7-cnt_bit];    //дʹ��ָ��
    else if((valid == 1'b1) && (cs_n == 1'b1))  //ʱ���߼���������Ӧ���ٶ෢һλ
        miso <= 1'b0;
    else
        miso <= 1'b0;

endmodule
