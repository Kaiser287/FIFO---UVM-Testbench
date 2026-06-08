//======================================================================
// File   : fifo_seq_pkg.sv
// Mô tả  : Sequence item + Sequences cho FIFO UVM Testbench
//======================================================================
package fifo_seq_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //==================================================================
    // Transaction item: mô tả một thao tác trên FIFO
    //==================================================================
    typedef enum bit [1:0] {OP_WRITE, OP_READ, OP_BOTH, OP_IDLE} fifo_op_e;

    class fifo_item extends uvm_sequence_item;
        rand fifo_op_e        op;        // loại thao tác
        rand bit [7:0]        din;       // dữ liệu ghi
        // các trường quan sát (do monitor điền)
        bit [7:0]             dout;
        bit                   full, empty, overflow, underflow;
        bit [4:0]             count;

        `uvm_object_utils_begin(fifo_item)
            `uvm_field_enum(fifo_op_e, op, UVM_ALL_ON)
            `uvm_field_int(din,  UVM_ALL_ON)
            `uvm_field_int(dout, UVM_ALL_ON)
            `uvm_field_int(full, UVM_ALL_ON)
            `uvm_field_int(empty,UVM_ALL_ON)
            `uvm_field_int(overflow, UVM_ALL_ON)
            `uvm_field_int(underflow,UVM_ALL_ON)
            `uvm_field_int(count, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "fifo_item");
            super.new(name);
        endfunction

        // Phân bố mặc định: ưu tiên ghi/đọc cân bằng
        constraint c_op_dist { op dist {OP_WRITE:=40, OP_READ:=40, OP_BOTH:=15, OP_IDLE:=5}; }
    endclass

    //==================================================================
    // Sequencer
    //==================================================================
    typedef uvm_sequencer #(fifo_item) fifo_sequencer;

    //==================================================================
    // Base sequence
    //==================================================================
    class fifo_base_seq extends uvm_sequence #(fifo_item);
        `uvm_object_utils(fifo_base_seq)
        int num = 20;
        function new(string name = "fifo_base_seq"); super.new(name); endfunction
    endclass

    //==================================================================
    // Write-only sequence: chỉ ghi để làm đầy FIFO
    //==================================================================
    class fifo_write_seq extends fifo_base_seq;
        `uvm_object_utils(fifo_write_seq)
        function new(string name = "fifo_write_seq"); super.new(name); endfunction
        task body();
            repeat (num) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { op == OP_WRITE; })
                    `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // Read-only sequence: chỉ đọc
    //==================================================================
    class fifo_read_seq extends fifo_base_seq;
        `uvm_object_utils(fifo_read_seq)
        function new(string name = "fifo_read_seq"); super.new(name); endfunction
        task body();
            repeat (num) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { op == OP_READ; })
                    `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // Random mixed sequence: ghi/đọc ngẫu nhiên (kiểm thử chức năng & hiệu năng)
    //==================================================================
    class fifo_random_seq extends fifo_base_seq;
        `uvm_object_utils(fifo_random_seq)
        function new(string name = "fifo_random_seq"); super.new(name); endfunction
        task body();
            repeat (num) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize())
                    `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // Overflow sequence: ghi liên tục nhiều hơn DEPTH để ép overflow
    //==================================================================
    class fifo_overflow_seq extends fifo_base_seq;
        `uvm_object_utils(fifo_overflow_seq)
        function new(string name = "fifo_overflow_seq"); super.new(name); endfunction
        task body();
            // ghi gấp đôi độ sâu để chắc chắn tràn
            repeat (40) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { op == OP_WRITE; })
                    `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    //==================================================================
    // Underflow sequence: đọc khi FIFO rỗng để ép underflow
    //==================================================================
    class fifo_underflow_seq extends fifo_base_seq;
        `uvm_object_utils(fifo_underflow_seq)
        function new(string name = "fifo_underflow_seq"); super.new(name); endfunction
        task body();
            repeat (10) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { op == OP_READ; })
                    `uvm_error("RAND","randomize failed")
                finish_item(it);
            end
        endtask
    endclass

endpackage