//======================================================================
// File   : fifo_dut.sv
// Mô tả  : Synchronous FIFO (DUT - Design Under Test)
//          FIFO đồng bộ tham số hóa với cờ full/empty/almost_*
//======================================================================
module sync_fifo #(
    parameter int WIDTH = 8,        // Độ rộng dữ liệu
    parameter int DEPTH = 16,       // Độ sâu FIFO
    parameter int AF_LVL = DEPTH-2, // Ngưỡng almost_full
    parameter int AE_LVL = 2        // Ngưỡng almost_empty
)(
    input  logic              clk,
    input  logic              rst_n,     // reset tích cực mức thấp
    input  logic              wr_en,     // yêu cầu ghi
    input  logic              rd_en,     // yêu cầu đọc
    input  logic [WIDTH-1:0]  din,       // dữ liệu vào
    output logic [WIDTH-1:0]  dout,      // dữ liệu ra
    output logic              full,
    output logic              empty,
    output logic              almost_full,
    output logic              almost_empty,
    output logic              overflow,  // báo lỗi ghi khi đầy
    output logic              underflow, // báo lỗi đọc khi rỗng
    output logic [$clog2(DEPTH):0] count // số phần tử hiện có
);

    localparam int AW = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [AW-1:0]    wr_ptr, rd_ptr;
    logic [AW:0]      cnt;

    // Ghi dữ liệu hợp lệ (có yêu cầu ghi và không đầy)
    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    // Con trỏ ghi
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        wr_ptr <= '0;
        else if (do_wr)    wr_ptr <= wr_ptr + 1'b1;
    end

    // Con trỏ đọc
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        rd_ptr <= '0;
        else if (do_rd)    rd_ptr <= rd_ptr + 1'b1;
    end

    // Bộ nhớ
    always_ff @(posedge clk) begin
        if (do_wr) mem[wr_ptr] <= din;
    end

    // Dữ liệu ra (đọc đồng bộ)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)     dout <= '0;
        else if (do_rd) dout <= mem[rd_ptr];
    end

    // Bộ đếm số phần tử
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cnt <= '0;
        else begin
            case ({do_wr, do_rd})
                2'b10:   cnt <= cnt + 1'b1; // chỉ ghi
                2'b01:   cnt <= cnt - 1'b1; // chỉ đọc
                default: cnt <= cnt;        // ghi+đọc hoặc không
            endcase
        end
    end

    // Cờ trạng thái
    assign count        = cnt;
    assign full         = (cnt == DEPTH);
    assign empty        = (cnt == 0);
    assign almost_full  = (cnt >= AF_LVL);
    assign almost_empty = (cnt <= AE_LVL);

    // Báo lỗi ngoại lệ
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            overflow  <= wr_en && full;
            underflow <= rd_en && empty;
        end
    end

endmodule