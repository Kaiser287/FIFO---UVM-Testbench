//======================================================================
// File   : tb_top.sv
// Mô tả  : Top-level testbench tạo waveform đẹp, gọn, dễ chụp báo cáo
//======================================================================
`timescale 1ns/1ps

module tb_top;

    localparam int WIDTH = 8;
    localparam int DEPTH = 16;

    // Clock 100 MHz
    logic clk = 0;
    always #5 clk = ~clk;

    // Interface
    fifo_if #(WIDTH, DEPTH) intf (clk);

    // DUT
    sync_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk          (clk),
        .rst_n        (intf.rst_n),
        .wr_en        (intf.wr_en),
        .rd_en        (intf.rd_en),
        .din          (intf.din),
        .dout         (intf.dout),
        .full         (intf.full),
        .empty        (intf.empty),
        .almost_full  (intf.almost_full),
        .almost_empty (intf.almost_empty),
        .overflow     (intf.overflow),
        .underflow    (intf.underflow),
        .count        (intf.count)
    );

    //==============================================================
    // Task tạo sóng đẹp: mọi kích thích đổi ở cạnh âm của clock
    //==============================================================
    task automatic idle_cycles(input int n);
        begin
            repeat (n) begin
                @(negedge clk);
                intf.wr_en <= 0;
                intf.rd_en <= 0;
                intf.din   <= '0;
            end
        end
    endtask

    task automatic fifo_write(input logic [WIDTH-1:0] data);
        begin
            @(negedge clk);
            intf.wr_en <= 1;
            intf.rd_en <= 0;
            intf.din   <= data;

            @(negedge clk);
            intf.wr_en <= 0;
            intf.din   <= '0;
        end
    endtask

    task automatic fifo_read;
        begin
            @(negedge clk);
            intf.rd_en <= 1;
            intf.wr_en <= 0;

            @(negedge clk);
            intf.rd_en <= 0;
        end
    endtask

    //==============================================================
    // Test chính: reset sạch + ghi/đọc đều để waveform cân đối
    //==============================================================
    initial begin
        // Khởi tạo sạch ngay từ đầu để tránh X/đỏ
        intf.rst_n = 0;
        intf.wr_en = 0;
        intf.rd_en = 0;
        intf.din   = '0;

        // Chỉ dump các tín hiệu cần cho báo cáo
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top.clk);
        $dumpvars(0, tb_top.intf.rst_n);
        $dumpvars(0, tb_top.intf.wr_en);
        $dumpvars(0, tb_top.intf.rd_en);
        $dumpvars(0, tb_top.intf.din);
        $dumpvars(0, tb_top.intf.dout);
        $dumpvars(0, tb_top.intf.count);
        $dumpvars(0, tb_top.intf.empty);
        $dumpvars(0, tb_top.intf.full);
        $dumpvars(0, tb_top.intf.almost_empty);
        $dumpvars(0, tb_top.intf.almost_full);
        $dumpvars(0, tb_top.intf.overflow);
        $dumpvars(0, tb_top.intf.underflow);

        // Reset
        idle_cycles(4);
        intf.rst_n <= 1;

        // Nghỉ 2 chu kỳ cho sóng dễ nhìn
        idle_cycles(2);

        // Ghi 4 mẫu, nhịp đều
        fifo_write(8'h11);
        idle_cycles(1);
        fifo_write(8'h22);
        idle_cycles(1);
        fifo_write(8'h33);
        idle_cycles(1);
        fifo_write(8'h44);

        // Nghỉ
        idle_cycles(2);

        // Đọc 2 mẫu
        fifo_read();
        idle_cycles(1);
        fifo_read();

        // Nghỉ
        idle_cycles(2);

        // Ghi tiếp 2 mẫu
        fifo_write(8'h55);
        idle_cycles(1);
        fifo_write(8'h66);

        // Nghỉ
        idle_cycles(2);

        // Đọc hết
        fifo_read();
        idle_cycles(1);
        fifo_read();
        idle_cycles(1);
        fifo_read();
        idle_cycles(1);
        fifo_read();

        // Kết thúc gọn đẹp
        idle_cycles(4);
        $finish;
    end

    // Timeout an toàn
    initial begin
        #3000;
        $fatal(1, "TIMEOUT");
    end

endmodule