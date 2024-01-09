 module DATA_INC_GEN#(
    parameter   CNT_CLK_2MHZ_MAX = 19,
    parameter   CNT_CLK_4MHZ_MAX = 9,
    parameter   CNT_MAX   = 12160
)
(
    input   wire           sys_clk     ,
    input   wire           rst_n       ,

    output  wire           data_out0    ,
    output  wire           data_out1    ,
    output  wire           data_out2    ,
    output  wire           data_out3    ,
    output  wire           data_out4    ,
    output  wire           data_out5    ,
    output  wire           data_out6    ,
    output  wire           data_out7    ,
    output  reg            clk_out      ,
    output  wire           frame_vaild  ,
    output  wire           line_vaild    
);

reg   [7:0]    data_inc ;
reg   [4:0]    clk_cnt ;
reg            clk_out_d ;

wire     clk;
pll_ip	pll_ip_inst (
	.inclk0 ( sys_clk ),
	.c0 ( clk )
	);

reg   [4:0]  clk_4mhz_cnt;
reg          clk_4mhz;

/*-----产生4MHz时钟-----*/
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        clk_4mhz_cnt <= 1'b0;
    else if(clk_4mhz_cnt == CNT_CLK_4MHZ_MAX)  
        clk_4mhz_cnt <= 1'b0;
    else
        clk_4mhz_cnt <= clk_4mhz_cnt + 1'b1;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        clk_4mhz <= 1'b0;
    else if(clk_4mhz_cnt == CNT_CLK_4MHZ_MAX)  
        clk_4mhz <= ~clk_4mhz;
    else
        clk_4mhz <= clk_4mhz;

/*-----产生2MHz时钟-----*/
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        clk_cnt <= 1'b0;
    else if(clk_cnt == CNT_CLK_2MHZ_MAX)  
        clk_cnt <= 1'b0;
    else
        clk_cnt <= clk_cnt + 1'b1;

//时钟脉冲，占空比不是50%
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        clk_out_d <= 1'b0;
    else if(clk_cnt == CNT_CLK_2MHZ_MAX)  
        clk_out_d <= ~clk_out_d;
    else
        clk_out_d <= clk_out_d;

/*-----生成数据-----*/
always @(posedge clk_out_d or negedge rst_n) begin
    if(!rst_n)
        data_inc <= 1'b0;
    else
        data_inc <= data_inc + 1'b1;
end

/*-----生成采样时钟-----*/
always @(posedge clk_4mhz or negedge rst_n) begin
    if(!rst_n)
        clk_out <= 1'b0;
    else
        clk_out <= clk_out_d;
end

assign data_out0 = data_inc[0];
assign data_out1 = data_inc[1];
assign data_out2 = data_inc[2];
assign data_out3 = data_inc[3];
assign data_out4 = data_inc[4];
assign data_out5 = data_inc[5];
assign data_out6 = data_inc[6];
assign data_out7 = data_inc[7];

assign frame_vaild = 1'b1;
assign line_vaild = 1'b1;

 endmodule