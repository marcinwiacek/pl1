module cpu2_test;

reg rst;

cpu2 cpu2(rst);

//always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu2_test);
    rst=1;
    rst=0;
    #10
    $finish();
end

endmodule