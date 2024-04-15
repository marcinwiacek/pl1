module cpu_test;

reg rst;
reg ram_clk;
reg sim_end;

cpu cpu(rst,sim_end,ram_clk);

always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu_test);
    ram_clk=0;
    rst=1;
    #400
    //$stop();
    sim_end=1;
    $finish();
end

endmodule
