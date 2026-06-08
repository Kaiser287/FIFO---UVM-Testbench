//======================================================================
// File   : fifo_if.sv
// Mô tả  : Interface kết nối DUT FIFO với UVM testbench
//======================================================================
interface fifo_if #(parameter int WIDTH = 8, parameter int DEPTH = 16)
                   (input logic clk);

    logic                     rst_n;
    logic                     wr_en;
    logic                     rd_en;
    logic [WIDTH-1:0]         din;
    logic [WIDTH-1:0]         dout;
    logic                     full;
    logic                     empty;
    logic                     almost_full;
    logic                     almost_empty;
    logic                     overflow;
    logic                     underflow;
    logic [$clog2(DEPTH):0]   count;

    // Clocking block cho Driver (lái tín hiệu vào, đọc tín hiệu trạng thái)
    clocking drv_cb @(posedge clk);
        default input #1step output #1ns;
        output wr_en, rd_en, din;
        input  full, empty, dout, count, overflow, underflow;
    endclocking

    // Clocking block cho Monitor (chỉ quan sát)
    clocking mon_cb @(posedge clk);
        default input #1step;
        input wr_en, rd_en, din, dout, full, empty;
        input almost_full, almost_empty, overflow, underflow, count, rst_n;
    endclocking

    modport DRV (clocking drv_cb, output rst_n, input clk);
    modport MON (clocking mon_cb, input clk);

endinterface