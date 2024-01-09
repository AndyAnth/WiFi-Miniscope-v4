`timescale  1ns/1ns

module  tb_delayn#(
    parameter   n = 5
);

reg daq_clk;
reg intr_out_pre;
wire intr_out;
reg rst_n;

initial begin
    daq_clk = 0;
    intr_out_pre = 0;
    rst_n = 0;

    #50 rst_n = 1;
end

always #10 daq_clk <= ~daq_clk;
always #100 intr_out_pre <= ~intr_out_pre;

delayn#(.n(n))delayn_inst(.clk(daq_clk), .rst_n(rst_n), .in(intr_out_pre), .out(intr_out));

endmodule