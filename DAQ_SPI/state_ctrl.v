module state_ctrl#(
    parameter   FOT    =   3'b001 ,   //帧空闲状态
    parameter   WR_EN  =   3'b010 ,   //行使能状态
    parameter   ROT    =   3'b100     //行空闲状态
)
(
    input   wire        clk         ,
    input   wire        rst_n       ,
    input   wire        line_vaild  ,
    input   wire        frame_vaild ,

    output  reg  [2:0]  state
);

//state:两段式状态机
always@(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        state   <=  FOT;    //frame_valid不使能时state处于FOT状态
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
                    state <= ROT;   //ROT的default状态
                    
        WR_EN:
                if(line_vaild == 1'b0)
                    state <= ROT;       //frame_valid使能但line_valid失能时进入ROT行空闲状态
                else if(frame_vaild == 1'b0)
                    state <= FOT;       //frame_valid失能时直接回到FOT状态
                else
                    state <= WR_EN;    //保持读取状态
                    
        default:    state   <=  FOT;
    endcase
end

endmodule