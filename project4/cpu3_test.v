module cpu3_test;

reg rst;

cpu3 cpu3(rst);

//always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu3_test);
    rst=1;
    rst=0;
    #6
    $finish();
end

endmodule