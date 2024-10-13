`timescale 1ns / 1ps

//Makes init of the SD card in the 1-bit SPI mode
//and dumps some debug into RS232 (115200, 8 bits (LSB first), 1 stop, no parity, for example cu -l /dev/ttyUSB0 -s 115200)

//1. https://www.sdcard.org/downloads/pls/ :
//SD Specifications Part 1 Physical Layer Simplified Specification Version 9.10 December 1, 2023
//2. https://electronics.stackexchange.com/questions/602105/how-can-i-initialize-use-sd-cards-with-spi
//
//FPGA board specs https://digilent.com/reference/programmable-logic/nexys-video/reference-manual :
//"All of the SD pins on the FPGA are wired to support full SD speeds in native interface mode,
//as shown in Fig. 12. The SPI interface is also available, if needed".
//...but Nexys Video seems to support 3,3V only, which the most probably means max. speed 25MB/s
//
//## UART
//set_property -dict { PACKAGE_PIN AA19  IOSTANDARD LVCMOS33 } [get_ports { uart_rx_out }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=uart_rx_out
//## SD card
// set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { sd_cclk }]; #IO_L12P_T1_MRCC_14 Sch=sd_cclk
// #set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { sd_cd }]; #IO_L20N_T3_A07_D23_14 Sch=sd_cd
// set_property -dict { PACKAGE_PIN W20   IOSTANDARD LVCMOS33 } [get_ports { sd_cmd }]; #IO_L12N_T1_MRCC_14 Sch=sd_cmd
// set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { sd_data0 }]; #IO_L14N_T2_SRCC_14 Sch=sd_d[0]
// #set_property -dict { PACKAGE_PIN T21   IOSTANDARD LVCMOS33 } [get_ports { sd_d1 }]; #IO_L4P_T0_D04_14 Sch=sd_d[1]
// #set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { sd_d2 }]; #IO_L6N_T0_D08_VREF_14 Sch=sd_d[2]
// set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { sd_cs }]; #IO_L18N_T2_A11_D27_14 Sch=sd_d[3]
// set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { sd_reset }]; #IO_L11N_T1_SRCC_14 Sch=sd_reset
module x (
    input clk,
    output bit uart_rx_out,
    output bit sd_cclk,  //400 Hz (init) or 25 Mhz (later)
    output bit sd_cmd,  //cmd input
    input sd_data0,  //cmd & data output
    output bit sd_reset,
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

  parameter STATE_WAIT_INIT = 1;
  parameter STATE_WAIT_CMD = 2;
  parameter STATE_INIT_OK = 3;
  parameter STATE_INIT_ERROR = 4;
  parameter STATE_SEND_CMD0 = 5;  //reset command
  parameter STATE_GET_CMD0_RESPONSE = 6;
  parameter STATE_SEND_CMD8 = 7;  //interface condition
  parameter STATE_GET_CMD8_RESPONSE = 8;
  parameter STATE_SEND_CMD41 = 9;  //send operation condition
  parameter STATE_GET_CMD41_RESPONSE = 10;
  parameter STATE_SEND_CMD58 = 11;  //read OCR & get voltage
  parameter STATE_GET_CMD58_RESPONSE = 12;
  parameter STATE_SEND_CMD58_2 = 14;  //read OCR & get card type
  parameter STATE_GET_CMD58_2_RESPONSE = 15;

  reg [0:55] cmd;
  reg [55:0] cmd_bits, cmd_expected_bits;
  reg [0:55] resp;
  reg [55:0] resp_bits, resp_expected_bits;
  reg cmd_started, resp_started;
  reg [20:0] clk_divider = CLK_DIVIDER_400kHz;
  reg [20:0] clk_counter;
  reg [7:0] state, next_state;
  reg [20:0] timeout_counter;
  reg [10:0] retry_counter;
  reg flag = 1;
  reg sd_cclk1;

  always @(negedge clk) begin
    if (flag) begin
      state <= STATE_WAIT_INIT;
      flag  <= 0;
      uart_buffer[uart_buffer_index++] = "a";
      sd_cmd <= 1;
      sd_cs <= 1;
      sd_cclk <= 0;
      sd_reset <= 0;
    end else if (state == STATE_WAIT_INIT) begin
      if (timeout_counter == 1000000) begin
        state <= STATE_SEND_CMD0;
        sd_cs <= 0;
      end
      timeout_counter <= timeout_counter + 1;
    end else if (state == STATE_SEND_CMD0) begin  //reset cmd
      uart_buffer[uart_buffer_index++] = "b";
      cmd <= 56'h40_00_00_00_00_95_00;
      cmd_bits <= 0;
      cmd_expected_bits <= 48;
      resp_expected_bits <= 8;
      state <= STATE_WAIT_CMD;
      next_state <= STATE_GET_CMD0_RESPONSE;
    end else if (state == STATE_GET_CMD0_RESPONSE) begin
      uart_buffer[uart_buffer_index++] = "c";
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] / 16 >= 10 ? resp[0:7] / 16 + 65 - 10 : resp[0:7] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] % 16 >= 10 ? resp[0:7] % 16 + 65 - 10 : resp[0:7] % 16 + 48;
      state <= (resp[0:7] != 1 /* not idle */ || resp_bits  > resp_expected_bits) && retry_counter < 10 ? STATE_SEND_CMD0 : STATE_SEND_CMD8;
      retry_counter <= retry_counter + 1;
    end else if (state == STATE_SEND_CMD8) begin  //interface condition
      uart_buffer[uart_buffer_index++] = "B";
      cmd <= 56'h48_00_00_01_AA_87_00;  //1 = support for 2.7-3.6 V, AA = check pattern
      cmd_bits <= 0;
      cmd_expected_bits <= 48;
      resp_expected_bits <= 40;
      state <= STATE_WAIT_CMD;
      next_state <= STATE_GET_CMD8_RESPONSE;
    end else if (state == STATE_GET_CMD8_RESPONSE) begin
      uart_buffer[uart_buffer_index++] = "C";
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] / 16 >= 10 ? resp[0:7] / 16 + 65 - 10 : resp[0:7] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] % 16 >= 10 ? resp[0:7] % 16 + 65 - 10 : resp[0:7] % 16 + 48;

      uart_buffer[
      uart_buffer_index++
      ] = resp[8:15] / 16 >= 10 ? resp[8:15] / 16 + 65 - 10 : resp[8:15] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[8:15] % 16 >= 10 ? resp[8:15] % 16 + 65 - 10 : resp[8:15] % 16 + 48;

      uart_buffer[
      uart_buffer_index++
      ] = resp[16:23] / 16 >= 10 ? resp[16:23] / 16 + 65 - 10 : resp[16:23] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[16:23] % 16 >= 10 ? resp[16:23] % 16 + 65 - 10 : resp[16:23] % 16 + 48;

      uart_buffer[
      uart_buffer_index++
      ] = resp[24:31] / 16 >= 10 ? resp[24:31] / 16 + 65 - 10 : resp[24:31] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[24:31] % 16 >= 10 ? resp[24:31] % 16 + 65 - 10 : resp[24:31] % 16 + 48;

      uart_buffer[
      uart_buffer_index++
      ] = resp[32:39] / 16 >= 10 ? resp[32:39] / 16 + 65 - 10 : resp[32:39] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[32:39] % 16 >= 10 ? resp[32:39] % 16 + 65 - 10 : resp[32:39] % 16 + 48;

      if (resp[0:7] == 5 /*illegal command*/ || (resp[0:7] == 1 /*idle */ && resp[24:31]==1 /*Voltage supported*/ && resp[32:39]==8'hAA)) begin
        state <= STATE_SEND_CMD58;
      end else begin
        state <= STATE_INIT_ERROR;
      end
    end else if (state == STATE_SEND_CMD58 || state == STATE_SEND_CMD58_2) begin
      uart_buffer[uart_buffer_index++] = "B";
      cmd <= 56'h7A_00_00_00_00_FD_00;
      cmd_bits <= 0;
      cmd_expected_bits <= 32;
      resp_expected_bits <= 40;
      state <= STATE_WAIT_CMD;
      next_state <= state == STATE_SEND_CMD58?STATE_GET_CMD58_RESPONSE:STATE_GET_CMD58_2_RESPONSE;
    end else if (state == STATE_GET_CMD58_RESPONSE) begin
      uart_buffer[uart_buffer_index++] = "C";
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] / 16 >= 10 ? resp[0:7] / 16 + 65 - 10 : resp[0:7] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] % 16 >= 10 ? resp[0:7] % 16 + 65 - 10 : resp[0:7] % 16 + 48;
      state <= STATE_SEND_CMD41;
    end else if (state == STATE_GET_CMD58_2_RESPONSE) begin
      uart_buffer[uart_buffer_index++] = "K";
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] / 16 >= 10 ? resp[0:7] / 16 + 65 - 10 : resp[0:7] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] % 16 >= 10 ? resp[0:7] % 16 + 65 - 10 : resp[0:7] % 16 + 48;
      clk_divider = CLK_DIVIDER_25Mhz;
      state <= STATE_INIT_OK;
    end else if (state == STATE_SEND_CMD41) begin
      uart_buffer[uart_buffer_index++] = "B";
      cmd <= 56'h69_40_00_00_00_77_00;  //HCS = 1 -> support SDHC/SDXC cards 
      cmd_bits <= 0;
      cmd_expected_bits <= 32;
      resp_expected_bits <= 8;
      state <= STATE_WAIT_CMD;
      next_state <= STATE_GET_CMD41_RESPONSE;
    end else if (state == STATE_GET_CMD41_RESPONSE) begin
      uart_buffer[uart_buffer_index++] = "C";
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] / 16 >= 10 ? resp[0:7] / 16 + 65 - 10 : resp[0:7] / 16 + 48;
      uart_buffer[
      uart_buffer_index++
      ] = resp[0:7] % 16 >= 10 ? resp[0:7] % 16 + 65 - 10 : resp[0:7] % 16 + 48;
      if (resp[0:7] == 1  /*idle*/) begin
        state <= STATE_SEND_CMD41;
        //state <= STATE_INIT_ERROR;
      end else if (resp[0:7] == 0) begin
        state <= STATE_SEND_CMD58_2;
      end else begin
        state <= STATE_INIT_ERROR;
      end
    end else if (state == STATE_WAIT_CMD && !sd_cclk1 && sd_cclk) begin
      if (!cmd_started) begin
        cmd_started <= 1;
        resp_bits <= 0;
        resp_started <= 0;
        timeout_counter <= 0;
        cmd_bits <= 1;
        sd_cmd <= cmd[0];
        uart_buffer[uart_buffer_index++] = cmd[0] + 48;
      end else if (cmd_bits < cmd_expected_bits) begin
        sd_cmd <= cmd[cmd_bits];
        uart_buffer[uart_buffer_index++] = cmd[cmd_bits] + 48;
        cmd_bits <= cmd_bits + 1;
      end else if (resp_bits < resp_expected_bits) begin
        sd_cmd <= 1;
        if (!sd_data0 || resp_started) begin
          resp_started <= 1;
          resp[resp_bits] <= sd_data0;
          resp_bits <= resp_bits + 1;
        end else begin
          resp = {0};
          timeout_counter <= timeout_counter + 1;
          if (timeout_counter == 20) resp_bits <= resp_expected_bits + 1;
        end
      end else begin
        sd_cmd <= 0;
        state <= next_state;
        cmd_started <= 0;
      end
    end
    if (clk_counter == clk_divider - 1) begin
      clk_counter <= 0;
      sd_cclk <= ~sd_cclk;
    end else begin
      clk_counter <= clk_counter + 1;
    end
    sd_cclk1 <= sd_cclk;
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
