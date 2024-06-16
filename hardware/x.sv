`timescale 1ns / 1ps

module x (
    input clk,
    output logic uart_rx_out
);

  //uart
  reg [7:0] input_data;
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
  reg [7:0] write_value;
  reg [5:0] read_address;
  wire [7:0] read_value;

  ram ram (
      .clk(clk),
      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value(write_value),
      .read_address(read_address),
      .read_value(read_value)
  );

  //machine state
  reg [ 6:0] state = 0;
  reg [10:0] addr = 0;

  always @(negedge clk) begin
    if (state == 0) begin
      read_address <= addr;
      state <= state + 1;
    end else if (state == 1 && read_value != 8'd0) begin
      input_data <= read_value;
      start <= 1;
      state <= state + 1;
    end else if (state == 2) begin
      start <= 0;
      if (busy == 0) begin
        addr  <= addr + 1;
        state <= 0;
      end
    end
  end

endmodule

module ram (
    input clk,
    input write_enabled,
    input [5:0] write_address,
    input [7:0] write_value,
    input [5:0] read_address,
    output reg [7:0] read_value
);

  reg [7:0] ram[0:32] = '{
      "P",
      "o",
      "z",
      "d",
      "r",
      "o",
      "w",
      "i",
      "e",
      "n",
      "i",
      "a",
      " ",
      "z",
      " ",
      "p",
      "l",
      "y",
      "t",
      "y",
      " ",
      "d",
      "l",
      "a",
      " ",
      "M",
      "i",
      "c",
      "h",
      "a",
      "l",
      "a",
      8'd0
  };

  always @(posedge clk) begin
    if (write_enabled) ram[write_address] <= write_value;
    read_value <= ram[read_address];
  end
endmodule

//115200, 8 bits, 1 stop, no parity
//values on tx: ...1, 0, (8 bits), 1... (every bit is sent CLK_PER_BYTE cycles)
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
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;

  reg [ 6:0] state = STATE_IDLE;
  reg [10:0] counter = CLK_PER_BYTE;

  assign tx = state == STATE_IDLE || state == STATE_STOP_BIT ? 1:(state == STATE_START_BIT?0:input_data[state-STATE_DATA_BIT_0]);
  assign busy = state != STATE_IDLE;

  always @(posedge clk, posedge start) begin
    if (state == STATE_IDLE) begin
      state <= start == 1? STATE_START_BIT:state;
    end else begin
      state   <= counter == 0 ? (state == STATE_STOP_BIT ? STATE_IDLE : state + 1) : state;
      counter <= counter == 0 ? CLK_PER_BYTE : counter - 1;
    end
  end


endmodule

