`timescale 1ns / 1ps

module x (
    input clk,
    output logic uart_rx_out
);

  //uart
  reg [7:0] uart_buffer[0:1024];
  reg [10:0] uart_buffer_index = 0;
  wire reset_uart_buffer_index;
  wire uart_buffer_full;
  
  uartx_tx_with_buffer uartx_tx_with_buffer (
    .clk(clk),
    .uart_buffer(uart_buffer),
    .uart_buffer_index(uart_buffer_index),
    .reset_uart_buffer_index(reset_uart_buffer_index),
    .uart_buffer_full(uart_buffer_full),
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
 // reg [20:0] clk_num = 0;
//  reg [10:0] run_complete=0;
  
  always @(negedge clk) begin
  //  if (run_complete==0) clk_num<=clk_num+1;
    if (state == 0) begin
      read_address <= addr;
      state <= state + 1;
    end else if (state == 1 && read_value != 8'd0) begin
      if (reset_uart_buffer_index) begin
        uart_buffer_index<= 0;
      end else if (!uart_buffer_full) begin
        uart_buffer[uart_buffer_index]<=read_value;
        uart_buffer_index<=uart_buffer_index+1;
        addr  <= addr + 1;
        state <= 0;
      end
  //  end else if (state==1  && read_value == 8'd0) begin
  //    if (reset_uart_buffer_index) begin
  //      uart_buffer_index<= 0;
   //   end else if (!uart_buffer_full) begin //FIXME
  //      if (clk_num!=0) begin
   //       uart_buffer[uart_buffer_index]<= clk_num %2 + 48; //ascii code
  //        uart_buffer_index<=uart_buffer_index+1;
  //        clk_num <= clk_num >> 1; 
  //      end
   //   end               
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

module uartx_tx_with_buffer (
  input clk,
  input [7:0] uart_buffer[0:1024],
  input [10:0] uart_buffer_index,
  output logic reset_uart_buffer_index,
  output logic uart_buffer_full,
  output logic tx
);

  reg [7:0] input_data;
  reg start = 0;
  wire busy;
  reg [10:0] uart_buffer_processed_index=0;
  
  assign reset_uart_buffer_index = uart_buffer_index != 0 && !busy && uart_buffer_index == uart_buffer_processed_index;
  assign uart_buffer_full = uart_buffer_index == 1000;
  
  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .busy(busy),
      .tx(tx)
  );
   
  always @(uart_buffer_index) begin
    if (busy) begin
      start <= 0;
    end else if (!busy && uart_buffer_processed_index < uart_buffer_index) begin
         input_data <= uart_buffer[uart_buffer_processed_index];
         uart_buffer_processed_index<= uart_buffer_processed_index+1;
         start <= 1;
    end else if (uart_buffer_processed_index > uart_buffer_index) begin
      uart_buffer_processed_index <= 0;
    end
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

