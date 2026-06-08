//======================================================================
// File   : run.f  (file list - thứ tự biên dịch quan trọng)
//======================================================================
fifo_dut.sv
fifo_if.sv
fifo_seq_pkg.sv
fifo_env_pkg.sv
fifo_test_pkg.sv
tb_top.sv

//======================================================================
// LỆNH CHẠY MÔ PHỎNG
//======================================================================
// --- Synopsys VCS ---
//   vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
//        -f run.f -l comp.log
//   ./simv +UVM_TESTNAME=fifo_random_test +UVM_VERBOSITY=UVM_LOW -l sim.log
//
// --- Mentor Questa/ModelSim ---
//   vlib work
//   vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f run.f
//   vsim -c tb_top +UVM_TESTNAME=fifo_random_test -do "run -all; quit"
//
// --- Cadence Xcelium ---
//   xrun -uvm -sv -f run.f +UVM_TESTNAME=fifo_random_test
//
// --- Danh sách test có thể chạy ---
//   fifo_smoke_test      : chức năng cơ bản ghi/đọc
//   fifo_random_test     : ngẫu nhiên (chức năng + hiệu năng)
//   fifo_overflow_test   : ngoại lệ tràn
//   fifo_underflow_test  : ngoại lệ đọc rỗng