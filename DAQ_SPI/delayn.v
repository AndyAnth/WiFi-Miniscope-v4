module delayn#(
    parameter n = 3
)
(
    input   wire    clk,        //input clock
    input   wire    rst_n,
    input   wire    in ,

    output  wire    out   //out contains the reasult of all 3 delays
);
reg [n-1:0]  temp;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        temp <= 1'b0;
    else 
        temp <= {temp[n-2:0], in};
end

assign out = temp[n-1] | temp[n-2] | temp[n-3];
endmodule