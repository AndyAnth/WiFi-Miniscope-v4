`timescale  1ns/1ns

module  SPI_transfer
(
    input   wire            sck         ,   //��������Ĵ���ʱ��
    input   wire            sys_rst_n   ,   //��λ�ź�,�͵�ƽ��Ч

    input   wire    [7:0]   data_in     ,
    //input   wire            start_trans ,
    input   wire            valid ,
    input   wire            cs_set,
    input   wire            cs_n,
    //input   wire            cs_set_pre,

    output  reg             miso        ,   //���������������
    output  reg     [2:0]   cnt_bit     ,    //���ؼ�����     
    output  reg     [15:0]   sent_cnt
    //output  reg   [3:0]  duty_cnt,
    //output  reg     state_flag

);

        
/*�����������ô��cs_set_pre�������ݿ���һ��*/

//reg   [3:0]  duty_cnt;   //������һ�����˶��ٸ�����

/*Ϊ�˱�֤�ߵ�ƽ����һ��ʱ�䣬������һ��״̬��־*/
//reg     state_flag;

/*
always@(posedge cs_set or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        duty_cnt <= 4'd0;
    else if(duty_cnt == 4'd8)    //ʱ���߼�������һ��
        duty_cnt <= 4'd0;
    else
        duty_cnt <= duty_cnt + 1'b1;

always@(negedge cs_set or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        state_flag <= 4'd0;
    else if(duty_cnt == 4'd8)      //ʱ���߼�������һ��
        state_flag <= 4'd1;
    //else if(duty_cnt == 4'd5)   //�������ģ��ģ����������
    //    state_flag <= 4'd0;
    else
        state_flag <= 4'd0;
*/

//cnt_bit:�ߵ�λ�Ե�������mosi���
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        cnt_bit <= 3'd0;
    //else if(start_trans == 1'b1)
    else if((valid == 1'b1) /*&& (cs_set == 1'b0)*/ && (cs_n == 1'b0))      //ʱ���߼�������һ��
        cnt_bit <= cnt_bit + 1'b1;
    else if(cnt_bit == 3'd7)
        cnt_bit <= 3'd0;
    else
        cnt_bit <= cnt_bit;

//mosi:����ʽ״̬���ڶ��Σ��߼����
always@(posedge sck or negedge sys_rst_n)  //��posedgeд�룬����������negedge������
    if(sys_rst_n == 1'b0) begin
        miso <= 1'b0;
        sent_cnt <= 1'b0;
    end
    //else if(start_trans == 1'b1)
    else if((valid == 1'b1) /*&& (cs_set == 1'b0)*/ && (cs_n == 1'b0)) begin
        miso <= data_in[7-cnt_bit];    //дʹ��ָ��
        sent_cnt <= sent_cnt + 1'b1;
    end
    else if((valid == 1'b1) /*&& (cs_set == 1'b1)*/ && (cs_n == 1'b1))  //ʱ���߼���������Ӧ���ٶ෢һλ
        miso <= 1'b0;
    else
        miso <= 1'b0;

endmodule
