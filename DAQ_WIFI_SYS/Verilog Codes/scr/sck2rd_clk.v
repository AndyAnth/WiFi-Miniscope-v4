module sck2rd_clk(
    input   wire    sck,
    input   wire    sys_rst_n,

    output  reg     rd_clk
);

reg     [2:0]   sck_cnt     ;
//sck_cnt�������Ǳ�ǵ�ǰ�ѷ��Ͷ������ݣ�Ϊ�˲���rd_clkʱ��
always@(posedge sck or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) 
        sck_cnt <=  2'd0;
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
        
endmodule