module delay(
    input   wire    clk,        //��׼ʱ��
    input   wire    in ,

    output  reg     out
);

always @(posedge clk)   out <= in;

endmodule