`timescale 1ns / 1ps

module x_out_of_order_test;

reg clk = 0;
reg x;


x_out_of_order x_out_of_order (
    .clk(clk), .x(x)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x_out_of_order.vcd");
    $dumpvars(0,x_out_of_order_test);
    #200
    $finish();
end

endmodule