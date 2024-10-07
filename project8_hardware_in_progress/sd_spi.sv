`timescale 1ns / 1ps

//https://www.sdcard.org/downloads/pls/ :
//SD Specifications Part 1 Physical Layer Simplified Specification Version 9.10 December 1, 2023
//SPI protocol is the most simple (+ has got only one bit parallel communication)
//additionally is not supported by SDUC card (> 2TB)
//
//https://digilent.com/reference/programmable-logic/nexys-video/reference-manual :
//"All of the SD pins on the FPGA are wired to support full SD speeds in native interface mode,
//as shown in Fig. 12. The SPI interface is also available, if needed".
//...but Nexys Video seems to support 3,3V only, which the most probably means max. speed 25MB/s
module x (
    input clk,
    output bit uart_rx_out,
    output bit sd_cclk = 0,  //400 Hz (init) or 25 Mhz (later)
    output bit sd_mosi_cmd,  //input for the card
    input bit sd_miso_data,
    output bit sd_cs

);

  //uart
  reg [7:0] uart_buffer[0:200];
  reg [6:0] uart_buffer_index = 0;
  wire reset_uart_buffer_index;
  wire uart_buffer_full;

  uartx_tx_with_buffer uartx_tx_with_buffer (
      .clk(clk),
      .uart_buffer(uart_buffer),
      .uart_buffer_available(uart_buffer_index),
      .reset_uart_buffer_available(reset_uart_buffer_index),
      .uart_buffer_full(uart_buffer_full),
      .tx(uart_rx_out)
  );

  parameter CLK_DIVIDER_400kHz = 100000000 / 400000;  //100 Mhz / 400 Khz
  parameter CLK_DIVIDER_25Mhz = 100000000 / 25000000;  //100 Mhz / 25 Mhz

  parameter STATE_WAIT = 1;
  parameter STATE_SEND_CMD0 = 2;  //reset command
  parameter STATE_GET_CMD0_RESPONSE = 3;
  parameter STATE_SEND_CMD8 = 4;

  reg [55:0] cmd;
  reg [55:0] cmd_bits, cmd_expected_bits;
  reg [55:0] resp;
  reg [55:0] resp_bits, resp_expected_bits;
  reg resp_started;
  reg [20:0] clk_divider = CLK_DIVIDER_400kHz;
  reg [20:0] clk_counter;
  reg [7:0] state, next_state;

  reg [10:0] retry_counter;
  bit flag = 1;

  always @(negedge clk) begin
    if (flag == 1) begin
      state <= STATE_SEND_CMD0;
      flag  <= 0;
      $display("a");
      uart_buffer[uart_buffer_index++] = "a";
      sd_cs <= 0;
    end else begin
      if (state == STATE_SEND_CMD0) begin
        $display("d");
        uart_buffer[uart_buffer_index++] = "d";
        cmd <= 56'hFF_40_00_00_00_00_95;
        cmd_bits <= 0;
        cmd_expected_bits <= 56;
        resp_expected_bits <= 8;
        state <= STATE_WAIT;
        next_state <= STATE_GET_CMD0_RESPONSE;
      end else if (state == STATE_GET_CMD0_RESPONSE) begin
        uart_buffer[
        uart_buffer_index++
        ] = resp[7:0] / 16 >= 10 ? resp[7:0] / 16 + 65 - 10 : resp[7:0] / 16 + 48;
        uart_buffer[
        uart_buffer_index++
        ] = resp[7:0] % 16 >= 10 ? resp[7:0] % 16 + 65 - 10 : resp[7:0] % 16 + 48;
        $display("e");
        state <= resp[7:0] != 1 && retry_counter < 10 ? STATE_SEND_CMD0 : STATE_SEND_CMD8;
        retry_counter <= retry_counter + 1;
      end else if (state ==STATE_WAIT && cmd_bits==cmd_expected_bits && resp_bits == resp_expected_bits) begin
        state <= next_state;
      end
    end
    clk_counter <= clk_counter == clk_divider - 1 ? 0 : clk_counter + 1;
    sd_cclk <= clk_counter == 0 ? ~sd_cclk : sd_cclk;
    if (clk_counter == 0 && sd_cclk == 1 && cmd_bits < cmd_expected_bits) begin
      sd_mosi_cmd <= cmd[cmd_bits];
      cmd_bits <= cmd_bits + 1;
      resp_bits <= 0;
      resp_started <= 0;
    end else if (clk_counter == 0 & sd_cclk==0 && cmd_bits==cmd_expected_bits && resp_bits<resp_expected_bits) begin
      //  sd_mosi_cmd <=1;  
      if (sd_miso_data == 0 || resp_started == 1) begin
        resp_started <= 1;
        resp[resp_bits] <= sd_miso_data;
        resp_bits <= resp_bits + 1;
      end
    end
  end
endmodule


module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:200],
    input [6:0] uart_buffer_available,
    output bit reset_uart_buffer_available,
    output bit uart_buffer_full,
    output bit tx
);

  bit [7:0] input_data;
  bit [6:0] uart_buffer_processed = 0;
  bit [3:0] uart_buffer_state = 0;
  bit start;
  wire complete;

  assign reset_uart_buffer_available = uart_buffer_available != 0 && uart_buffer_available == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
  assign uart_buffer_full = uart_buffer_available == 199 ? 1 : 0;
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
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... 
//(we make some delay in the end before next seq; every bit is sent CLK_PER_BIT cycles)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output bit complete,
    output bit uarttx
);

  parameter CLK_PER_BIT = 100000000 / 115200;  //100 Mhz / transmission speed in bits per second

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  bit [ 6:0] uart_tx_state = STATE_IDLE;
  bit [10:0] counter = CLK_PER_BIT;

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
