module state_ctrl#(
    parameter   FOT    =   3'b001 ,   //֡����״̬
    parameter   WR_EN  =   3'b010 ,   //��ʹ��״̬
    parameter   ROT    =   3'b100     //�п���״̬
)
(
    input   wire        clk         ,
    input   wire        rst_n       ,
    input   wire        line_vaild  ,
    input   wire        frame_vaild ,

    output  reg  [2:0]  state
);

//state:����ʽ״̬��
always@(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
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

endmodule