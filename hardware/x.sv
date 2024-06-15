`timescale 1ns / 1ps

module x (
    output logic [7:0] led,
    input clk,
    input btnc,
    output logic uart_rx_out

);

  //uart
  reg [7:0] input_data = 8'h40;
  reg start = 0;
  wire busy;

  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .busy(busy),
      .tx(uart_rx_out)

  );

  //ram
  reg write_enabled;
  reg [5:0] write_address;
  reg [5:0] read_address = 0;
  reg [7:0] write_value;
  wire [7:0] read_value;

  reg [2:0] state = 0;
  reg[10:0] addr=0;

  parameter STATE0 = 0;
  parameter STATE1 = 1;
  parameter STATE2 = 2;
  parameter STATE3 = 3;

  always @(posedge clk) begin
     if (state == 0) begin
       read_address<=addr;
       state <= state+1;
     end else if (state==1 && read_value!=8'd0) begin
         input_data<=read_value;
         start<=1;
         state<=state+1;
       
     end else if (state== 2) begin
         start<=0;
         if (busy==0) state=0
     end
    /*if (state ==STATE0) begin
  in<=8'h7B;
  txStart<=1;
     state<=STATE0;
  end else if (state==STATE1) begin
   read_address <= (read_address+1) % 8;
   state<=STATE2;
  end else if (state==STATE2) begin
     led[1]<=read_value==STATE1;
  led[2]<=read_value==STATE2;
  led[3]<=read_value==STATE3;
    $display($time,read_value);     
state<=1;      
  end
 
  
   led[5]<=btnc;
   */
  end

  //always_comb begin
  //if (btnc == 1) begin
  /*write_enabled<=1;
write_address<=pc;
write_value<=0;
  read_address<=pc;*/
  // led[1]<=btnc;
  // led[3]<=btnc;
  //pc<=pc<5?pc+1:0;
  //$display($time,pc);
  //end
  //end


  ram ram (
      .clk(clk),

      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value  (write_value),

      .read_address(read_address),
      .read_value  (read_value)
  );


endmodule


module ram (
    input clk,
    input write_enabled,
    input [5:0] write_address,
    input [7:0] write_value,
    input [5:0] read_address,
    output reg [15:0] read_value
);

  reg [7:0] ram[0:31] =  '{"P","o","z","d","r","o","w","i","e","n","i","a", " ","z", " ", "p", "l","y","t","y","d","l","a"," ","M","i","c","h","a","l","a",8'd0};
  // '{16'h02, 16'h02, 16'h04, 16'h03, 16'h02, 16'h02, 16'h02, 16'h02};

  always @(posedge clk) begin
    if (write_enabled) ram[write_address] <= write_value;
    read_value <= ram[read_address];
  end
endmodule

//115200, 8 bits, 1 stop
//values on tx: ...1, 0, (8 bits), 1... (every bit sent with CLK_PER_BYTE length)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output logic busy,
    output logic tx
);

  parameter CLK_PER_BYTE = 100000000 / 115200;  //100 Mhz / transmission speed
  parameter STATE_IDLE = 0;
  parameter STATE_START_BIT = 1;
  parameter STATE_DATA_BIT_0 = 2;
  parameter STATE_DATA_BIT_1 = 3;
  parameter STATE_DATA_BIT_2 = 4;
  parameter STATE_DATA_BIT_3 = 5;
  parameter STATE_DATA_BIT_4 = 6;
  parameter STATE_DATA_BIT_5 = 7;
  parameter STATE_DATA_BIT_6 = 8;
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;

  reg [ 5:0] state = STATE_IDLE;
  reg [10:0] counter = CLK_PER_BYTE;

  assign tx = state == STATE_IDLE?1:(state == STATE_START_BIT?0:(state == STATE_STOP_BIT?1:input_data[state-STATE_DATA_BIT_0]));
  assign busy = state!= STATE_IDLE;
  
  always @(posedge clk, posedge start) begin
    if (start && state == STATE_IDLE) begin
      state<=STATE_START_BIT;
    end else begin
      state <= counter == 0?(state == STATE_STOP_BIT ? STATE_IDLE : state + 1):state;
      counter <= counter == 0 ? CLK_PER_BYTE : counter - 1;
    end
  end


endmodule
