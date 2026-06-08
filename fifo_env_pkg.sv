//======================================================================
// File   : fifo_env_pkg.sv
// Mô tả  : Driver, Monitor, Scoreboard, Agent, Environment cho FIFO TB
//======================================================================
package fifo_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fifo_seq_pkg::*;

    //==================================================================
    // DRIVER: nhận item từ sequencer, lái tín hiệu lên interface
    //==================================================================
    class fifo_driver extends uvm_driver #(fifo_item);
        `uvm_component_utils(fifo_driver)
        virtual fifo_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF","Driver không lấy được virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            // Khởi tạo
            vif.drv_cb.wr_en <= 0;
            vif.drv_cb.rd_en <= 0;
            vif.drv_cb.din   <= 0;
            forever begin
                fifo_item it;
                seq_item_port.get_next_item(it);
                drive(it);
                seq_item_port.item_done();
            end
        endtask

        task drive(fifo_item it);
            @(vif.drv_cb);
            case (it.op)
                OP_WRITE: begin vif.drv_cb.wr_en<=1; vif.drv_cb.rd_en<=0; vif.drv_cb.din<=it.din; end
                OP_READ : begin vif.drv_cb.wr_en<=0; vif.drv_cb.rd_en<=1; end
                OP_BOTH : begin vif.drv_cb.wr_en<=1; vif.drv_cb.rd_en<=1; vif.drv_cb.din<=it.din; end
                OP_IDLE : begin vif.drv_cb.wr_en<=0; vif.drv_cb.rd_en<=0; end
            endcase
            @(vif.drv_cb);
            vif.drv_cb.wr_en <= 0;
            vif.drv_cb.rd_en <= 0;
        endtask
    endclass

    //==================================================================
    // MONITOR: quan sát interface, phát các transaction qua analysis port
    //==================================================================
    class fifo_monitor extends uvm_monitor;
        `uvm_component_utils(fifo_monitor)
        virtual fifo_if vif;
        uvm_analysis_port #(fifo_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF","Monitor không lấy được virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.wr_en || vif.mon_cb.rd_en) begin
                    fifo_item it = fifo_item::type_id::create("mon_it");
                    it.din   = vif.mon_cb.din;
                    it.dout  = vif.mon_cb.dout;
                    it.full  = vif.mon_cb.full;
                    it.empty = vif.mon_cb.empty;
                    it.overflow  = vif.mon_cb.overflow;
                    it.underflow = vif.mon_cb.underflow;
                    it.count = vif.mon_cb.count;
                    if (vif.mon_cb.wr_en && vif.mon_cb.rd_en) it.op = OP_BOTH;
                    else if (vif.mon_cb.wr_en)                it.op = OP_WRITE;
                    else                                      it.op = OP_READ;
                    ap.write(it);
                end
            end
        endtask
    endclass

    //==================================================================
    // SCOREBOARD: mô hình tham chiếu FIFO (queue) so sánh dout
    //==================================================================
    `uvm_analysis_imp_decl(_fifo)
    class fifo_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(fifo_scoreboard)
        uvm_analysis_imp_fifo #(fifo_item, fifo_scoreboard) imp;

        bit [7:0] ref_q [$];      // mô hình tham chiếu
        localparam int DEPTH = 16;
        int n_write, n_read, n_pass, n_fail, n_ovf, n_unf;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            imp = new("imp", this);
        endfunction

        // Hàm nhận transaction từ monitor
        function void write_fifo(fifo_item it);
            // Xử lý ghi
            if (it.op == OP_WRITE || it.op == OP_BOTH) begin
                if (ref_q.size() < DEPTH) begin
                    ref_q.push_back(it.din);
                    n_write++;
                end else begin
                    n_ovf++;
                    `uvm_info("SCB", $sformatf("Overflow đúng kỳ vọng (đầy), din=%0h", it.din), UVM_HIGH)
                end
            end
            // Xử lý đọc - so sánh dout với mô hình tham chiếu
            if (it.op == OP_READ || it.op == OP_BOTH) begin
                if (ref_q.size() > 0) begin
                    bit [7:0] exp = ref_q.pop_front();
                    n_read++;
                    if (exp === it.dout) begin
                        n_pass++;
                        `uvm_info("SCB", $sformatf("PASS đọc: exp=%0h got=%0h", exp, it.dout), UVM_HIGH)
                    end else begin
                        n_fail++;
                        `uvm_error("SCB", $sformatf("FAIL đọc: exp=%0h got=%0h", exp, it.dout))
                    end
                end else begin
                    n_unf++;
                    `uvm_info("SCB", "Underflow đúng kỳ vọng (rỗng)", UVM_HIGH)
                end
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB", "================ KẾT QUẢ SCOREBOARD ================", UVM_LOW)
            `uvm_info("SCB", $sformatf("Tổng ghi=%0d  đọc=%0d", n_write, n_read), UVM_LOW)
            `uvm_info("SCB", $sformatf("PASS=%0d  FAIL=%0d", n_pass, n_fail), UVM_LOW)
            `uvm_info("SCB", $sformatf("Overflow=%0d  Underflow=%0d", n_ovf, n_unf), UVM_LOW)
            if (n_fail == 0) `uvm_info("SCB","*** TEST PASSED ***", UVM_LOW)
            else             `uvm_error("SCB","*** TEST FAILED ***")
        endfunction
    endclass

    //==================================================================
    // AGENT: đóng gói sequencer + driver + monitor
    //==================================================================
    class fifo_agent extends uvm_agent;
        `uvm_component_utils(fifo_agent)
        fifo_sequencer sqr;
        fifo_driver    drv;
        fifo_monitor   mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = fifo_monitor::type_id::create("mon", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sqr = fifo_sequencer::type_id::create("sqr", this);
                drv = fifo_driver::type_id::create("drv", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            if (get_is_active() == UVM_ACTIVE)
                drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    //==================================================================
    // ENVIRONMENT: chứa agent + scoreboard, đấu nối analysis port
    //==================================================================
    class fifo_env extends uvm_env;
        `uvm_component_utils(fifo_env)
        fifo_agent      agt;
        fifo_scoreboard scb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = fifo_agent::type_id::create("agt", this);
            scb = fifo_scoreboard::type_id::create("scb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agt.mon.ap.connect(scb.imp);
        endfunction
    endclass

endpackage