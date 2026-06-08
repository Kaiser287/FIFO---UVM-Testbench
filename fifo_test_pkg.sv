//======================================================================
// File   : fifo_test_pkg.sv
// Mô tả  : Base test + các testcase (chức năng, hiệu năng, ngoại lệ)
//======================================================================
package fifo_test_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import fifo_seq_pkg::*;
    import fifo_env_pkg::*;

    //==================================================================
    // BASE TEST
    //==================================================================
    class fifo_base_test extends uvm_test;
        `uvm_component_utils(fifo_base_test)
        fifo_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = fifo_env::type_id::create("env", this);
        endfunction

        // In cấu trúc topology
        function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction
    endclass

    //==================================================================
    // TC1: Smoke test - ghi rồi đọc tuần tự (kiểm thử chức năng cơ bản)
    //==================================================================
    class fifo_smoke_test extends fifo_base_test;
        `uvm_component_utils(fifo_smoke_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fifo_write_seq wseq;
            fifo_read_seq  rseq;
            phase.raise_objection(this);
            wseq = fifo_write_seq::type_id::create("wseq"); wseq.num = 8;
            rseq = fifo_read_seq::type_id::create("rseq");  rseq.num = 8;
            wseq.start(env.agt.sqr);
            rseq.start(env.agt.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC2: Random test - ghi/đọc ngẫu nhiên (chức năng + hiệu năng)
    //==================================================================
    class fifo_random_test extends fifo_base_test;
        `uvm_component_utils(fifo_random_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fifo_random_seq seq;
            phase.raise_objection(this);
            seq = fifo_random_seq::type_id::create("seq"); seq.num = 200;
            seq.start(env.agt.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC3: Overflow test - kiểm thử trường hợp ngoại lệ tràn FIFO
    //==================================================================
    class fifo_overflow_test extends fifo_base_test;
        `uvm_component_utils(fifo_overflow_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fifo_overflow_seq seq;
            phase.raise_objection(this);
            seq = fifo_overflow_seq::type_id::create("seq");
            seq.start(env.agt.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    //==================================================================
    // TC4: Underflow test - kiểm thử trường hợp ngoại lệ đọc khi rỗng
    //==================================================================
    class fifo_underflow_test extends fifo_base_test;
        `uvm_component_utils(fifo_underflow_test)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            fifo_underflow_seq seq;
            phase.raise_objection(this);
            seq = fifo_underflow_seq::type_id::create("seq");
            seq.start(env.agt.sqr);
            phase.drop_objection(this);
        endtask
    endclass

endpackage