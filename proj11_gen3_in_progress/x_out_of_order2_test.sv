`timescale 1ns / 1ps

module x_out_of_order2_test;

reg clk = 0;
reg x;


x_out_of_order2 x_out_of_order2 (
    .clk(clk), .x(x)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x_out_of_order2.vcd");
    $dumpvars(0,x_out_of_order2_test);
    #200
    $finish();
end

endmodule