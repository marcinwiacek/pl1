`timescale 1ns / 1ps

module crc_test;

reg clk;
  reg [0:47] cmd;
  reg temp_crc7;
  
always #1 clk = ~clk;

integer i;

initial begin
    //$dumpfile("x_async.vcd");
    //$dumpvars(0,x_async_test);
    cmd = 48'h77_00_00_00_00_01;
    #1
    for (i=0;i<40;i=i+1) begin
   //Generator polynomial x^7 + x^3 + 1
               #1
               /*temp = cmd[40];
               cmd[40] = cmd[41];
               cmd[41] = cmd[42];
               cmd[42] = cmd[43];
               cmd[43] = cmd[44]^(cmd[i] ^ temp);
               cmd[44] = cmd[45];
               cmd[45] = cmd[46];
               cmd[46] = cmd[i] ^ temp;*/
               
               temp_crc7 = cmd[40];
               cmd[40] = cmd[41];
               cmd[41] = cmd[42];
               cmd[42] = cmd[43];
               cmd[43] = cmd[44]^(cmd[i] ^ temp_crc7);
               cmd[44] = cmd[45];
               cmd[45] = cmd[46];
               cmd[46] = cmd[i] ^ temp_crc7;
               
               /*temp = cmd[46];
               cmd[46] = cmd[45];              
               cmd[45] = cmd[44];              
               cmd[44] = cmd[43];
               cmd[43] = cmd[42]^( cmd[i] ^ temp);
               cmd[42] = cmd[41];
               cmd[41] = cmd[40];
               cmd[40] = cmd[i] ^ temp;*/
    end
    $display(cmd[0:7]);
    $display(cmd[40:47]);
    $finish();
end

endmodule