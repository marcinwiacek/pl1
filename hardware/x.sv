`timescale 1ns / 1ps

module x (
    input clk,
    output logic uart_rx_out
);

  //uart
  reg [7:0] uart_buffer[0:128];
  reg [6:0] uart_buffer_available = 0;
  wire reset_uart_buffer_available;
  wire uart_buffer_full;

  uartx_tx_with_buffer uartx_tx_with_buffer (
      .clk(clk),
      .uart_buffer(uart_buffer),
      .uart_buffer_available(uart_buffer_available),
      .reset_uart_buffer_available(reset_uart_buffer_available),
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
  reg [ 6:0] main_state = 0;
  reg [10:0] addr = 0;
  reg unsigned [20:0] clk_num = 0;
  reg [10:0] run_complete = 0;

  always @(posedge clk) begin
    if (run_complete == 0) clk_num <= clk_num + 1;
    if (main_state == 0) begin
      read_address <= addr;
      main_state   <= main_state + 1;
    end else if (read_value != 8'd0) begin
      if (reset_uart_buffer_available) begin
        uart_buffer_available <= 0;
      end else if (!uart_buffer_full) begin
        uart_buffer[uart_buffer_available] <= read_value;
        uart_buffer_available <= uart_buffer_available + 1;
        addr <= addr + 1;
        main_state <= 0;
      end
    end else if (main_state == 1 && read_value == 8'd0) begin
    run_complete <= 1;
      if (reset_uart_buffer_available) begin
        uart_buffer_available <= 0;
      end else if (!uart_buffer_full) begin
        if (clk_num !=0) begin
          uart_buffer[uart_buffer_available] <= clk_num % 10 + 48;  //ascii code
          $display($time, clk_num % 10 , " " ,clk_num);
          uart_buffer_available <= uart_buffer_available + 1;
          clk_num <= clk_num /10;
        end
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

  always @(negedge clk) begin
    if (write_enabled) ram[write_address] <= write_value;
    read_value <= ram[read_address];
  end
endmodule

module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:128],
    input [6:0] uart_buffer_available,
    output logic reset_uart_buffer_available,
    output logic uart_buffer_full,
    output logic tx
);

  reg [7:0] input_data;
  reg start;
  wire complete;
  reg [6:0] uart_buffer_processed = 0;
  reg [3:0] uart_buffer_state = 0;

  assign reset_uart_buffer_available = uart_buffer_available != 0 && uart_buffer_available == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
  assign uart_buffer_full = uart_buffer_available == 127 ? 1 : 0;
  assign start = uart_buffer_state == 1;

  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .complete(complete),
      .uarttx(tx)
  );

  always @(posedge clk) begin
    if (uart_buffer_state == 0) begin
      if (uart_buffer_available > 0 && uart_buffer_processed < uart_buffer_available) begin
        input_data <= uart_buffer[uart_buffer_processed];
        uart_buffer_state <= uart_buffer_state + 1;
        uart_buffer_processed <= uart_buffer_processed + 1;
      end else if (uart_buffer_processed > uart_buffer_available) begin
        uart_buffer_processed <= 0;
      end
    end else if (uart_buffer_state == 1) begin
      if (!complete) uart_buffer_state <= uart_buffer_state + 1;
    end else if (uart_buffer_state == 2) begin
      if (complete) uart_buffer_state <= 0;
    end
  end

endmodule


//115200, 8 bits (LSB first), 1 stop, no parity
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... (I make some delay and start with next seq; every bit is sent CLK_PER_BIT cycles)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output logic complete,
    output logic uarttx
);

  parameter CLK_PER_BIT = 100000000 / 115200;  //100 Mhz / transmission speed in bits per second

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  reg [ 6:0] uart_tx_state = STATE_IDLE;
  reg [10:0] counter = CLK_PER_BIT;

  assign uarttx = uart_tx_state == STATE_IDLE || uart_tx_state == STATE_STOP_BIT ? 1:(uart_tx_state == STATE_START_BIT ? 0:input_data[uart_tx_state-STATE_DATA_BIT_0]);
  assign complete = uart_tx_state == STATE_IDLE;

  always @(negedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      uart_tx_state <= start ? STATE_START_BIT : STATE_IDLE;
    end else begin
      uart_tx_state <= counter == 0 ? (uart_tx_state== STATE_STOP_BIT? STATE_IDLE : uart_tx_state + 1) : uart_tx_state;
      counter <= counter == 0 ? CLK_PER_BIT : counter - 1;
    end
  end
endmodule

