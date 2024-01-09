module delay(
    input   wire    clk,        //»ù×¼Ê±ÖÓ
    input   wire    in ,

    output  reg     out
);

always @(posedge clk)   out <= in;

endmodule