module cpu_test;

reg rst;
reg ram_clk;

cpu cpu(rst,ram_clk);

always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu_test);
    ram_clk=0;
    rst=1;
    #600
    $finish();
end

endmodule
