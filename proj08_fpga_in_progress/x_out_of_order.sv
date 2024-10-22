`timescale 1ns / 1ps

parameter HARDWARE_DEBUG = 0;

parameter RAM_WRITE_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter RAM_READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info


module x_out_of_order(
input clk
    );    
    
      bit write_enabled = 0;
  bit [15:0] write_address;
  bit [15:0] write_value;
  bit [15:0] read_address;
  wire [15:0] read_value;
  bit [15:0] read_address2;
  wire [15:0] read_value2;

  single_blockram single_blockram (
      .clk(clk),
      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value(write_value),
      .read_address(read_address),
      .read_value(read_value),
      .read_address2(read_address2),
      .read_value2(read_value2)
  );
  
  always @(posedge clk) begin
    
  end
endmodule

module single_blockram (
    input clk,
    write_enabled,
    input bit [15:0] write_address,
    write_value,
    read_address,
    read_address2,
    output bit [15:0] read_value,
    read_value2
);

  /*  reg [15:0] ram[0:67];
      initial begin  //DEBUG info
        $readmemh("rom4.mem", ram);  //DEBUG info
      end  //DEBUG info
*/

  // verilog_format:off
   //(* ram_style = "block" *)
   bit [15:0] ram  [0:699]= {  // in Vivado (required by board)
  //  reg [0:559] [15:0] ram = {  // in iVerilog

      //first process - 2 pages (200 elements)
      //page 1 (100 elements)
      16'd0200, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'd0050, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,

      16'd0006, //mmu segment length
      16'h0001, //physical segment address for mmu logical page 1 or 0 (not assigned)
      16'h0000, //physical segment address for mmu logical page 2 or 0 (not assigned)
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000, //next mmu address or 0 (not assigned)

      16'h1210, 16'd2613, //value to reg // not used for anything usefull, just for debugging
      16'h0e10, 16'd0290, //save to ram // not used for anything usefull, just for debugging
      16'h0911, 16'd0100, //ram to reg // not used for anything usefull, just for debugging
      16'h0e10, 16'd0212, //save to ram // not used for anything usefull, just for debugging
      16'h0c01, 16'h0001, //unknown // not used for anything usefull, just for debugging
      16'h0c01, 16'h0002, //unknown // not used for anything usefull, just for debugging
      16'h1202, 16'h0003, //num2reg // not used for anything usefull, just for debugging
      16'h1800, 16'h0007, //process end
      16'hfb00, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,

      //page 2 (100 elements)
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,

      //second process - 3 pages (300 elements) + 2 pages (200 elements) new process nr 3
      //page 3 (100 elements)
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only
      16'd0050, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000, 

      16'd0006, //mmu segment length
      16'h0003, //physical segment address for mmu logical page 1 or 0 (not assigned)
      16'h0004, //physical segment address for mmu logical page 2 or 0 (not assigned)
      16'h0005,
      16'h0006,
      16'h0000,
      16'h0000,
      16'h0000, //next mmu address or 0 (not assigned)

      16'h1210, 16'd2612, //value to reg // not used for anything usefull, just for debugging
      16'h1902, 16'h0003, //split process process pages 3-4 (page 6 & 7)
      //16'h0000, 16'h0000,
      //16'h0000, 16'h0000,
       16'h0911, 16'd0101, //ram to reg // not used for anything usefull, just for debugging
       16'h0911, 16'd0102, //ram to reg // not used for anything usefull, just for debugging
    //  16'h1210, 16'd2615, //value to reg // not used for anything usefull, just for debugging
//      16'h0e10, 16'd0100, //save to ram // not used for anything usefull, just for debugging
      16'h1b37, 16'h0101, //int
      16'h1e00, 16'd0201, //in2ram
      16'h1b37, 16'h0202, //int
      16'h1f00, 16'd0002, //ret in2ram
      16'hfe00, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,

      //page 4 (100 elements)
      16'h0000,"Po",    "zd",    "ro",    "wi",    "en",    "ia",    " z"    ," p",    "ly",
      "ty",    " d",    "la",    " M",    "ic",    "ha",    "la",    16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,

      //page 5 (100 elements)
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,

      //third process - 2 pages (200 elements)
      //page 6 (100 elements)
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only
      16'd0050, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,

      16'd0006, //mmu segment length
      16'h0000, //physical segment address for mmu logical page 1 or 0 (not assigned)
      16'h0000, //physical segment address for mmu logical page 2 or 0 (not assigned)
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000, //next mmu address or 0 (not assigned)

      16'h1a37, 16'h0101, //reg int
      16'h0911, 16'd0150, //ram to reg // not used for anything usefull, just for debugging
      16'h1210, 16'h0a35, //value to reg // not used for anything usefull, just for debugging
      16'h1d10, 16'd0101, //ram2out
      16'h1c37, 16'd0000, //int ret
      16'hff00, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,

      //page 7 (100 elements)
      "AB",        "CD",16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000
    };

  // verilog_format:on

  assign read_value  = ram[read_address];
  assign read_value2 = ram[read_address2];

  always @(posedge clk) begin
    // if (write_enabled) 
    if (write_enabled && RAM_WRITE_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display($time, " ram write ", write_address, " = ", write_value);  //DEBUG info
    if (RAM_READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display($time, " ram read ", read_address, " = ", ram[read_address]);  //DEBUG info

    if (write_enabled) ram[write_address] <= write_value;
  end
endmodule
