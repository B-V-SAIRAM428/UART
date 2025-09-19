`include "uvm_macros.svh"
import uvm_pkg :: *;

//////////// Interface ///////

interface intf (input logic clk, input logic rst);
	logic en;
	logic [7:0] data_in;
	logic data_out;

endinterface

///////// Transaction ////////

class tx_trans extends uvm_sequence_item;
	rand logic en;
	rand logic [7:0] data_in;
	logic data_out;
	logic [10:0] data; 
	
	function new(string name = "tx_trans");
		super.new(name);
	endfunction 
	
	`uvm_object_utils_begin(tx_trans)
		`uvm_field_int(en,UVM_ALL_ON)
		`uvm_field_int(data_in,UVM_ALL_ON)
		`uvm_field_int(data_out,UVM_ALL_ON)
		`uvm_field_int(data,UVM_ALL_ON)
	`uvm_object_utils_end
endclass

///////////// Sequence /////////

class tx_seq extends uvm_sequence;
	`uvm_object_utils(tx_seq)
	
	function new(string name ="tx_seq");
		super.new(name);
	endfunction 
	
	task body ();
		repeat(5) begin 
			tx_trans trans;
			trans = tx_trans :: type_id :: create("trans");
			start_item(trans);
			assert (trans.randomize() with {trans.en ==1;});
			finish_item(trans);
			
			#200;
		end
	endtask
endclass

////////// Sequencer ////////

class tx_sequ extends uvm_sequencer#(tx_trans);
	`uvm_component_utils(tx_sequ)
	
	function new(string name = "tx_sequ", uvm_component parent);
		super.new(name, parent);
	endfunction
endclass

///////// Driver ///////////

class tx_dri extends uvm_driver#(tx_trans);
	`uvm_component_utils(tx_dri)
	virtual intf vif;
	logic [3:0]  cnt;
	
	function new(string name ="tx_dri", uvm_component parent);
		super.new(name, parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);	
		if(!uvm_config_db#(virtual intf) :: get(this, "", "vif", vif))
			`uvm_fatal("Driver","Virtual interface not found")
	endfunction 

	task run_phase(uvm_phase phase);
		wait(!vif.rst);
		@(posedge vif.clk);
		
		forever begin
			tx_trans trans;
			seq_item_port.get_next_item(trans);
			
			@(posedge vif.clk);
			vif.en = trans.en;
			vif.data_in = trans.data_in;
			@(posedge vif.clk);
			vif.en = 0;
			repeat(15) @(posedge vif.clk); 
			
			seq_item_port.item_done();
		end
	endtask
endclass

///////////// Monitor ///////////////

class tx_mon extends uvm_monitor;
	`uvm_component_utils(tx_mon)
	uvm_analysis_port#(tx_trans) ap;
	logic [10:0] collected_frame;
	logic [7:0] input_data;
	logic input_en;
	int bit_count;
	bit transmission_started;
	virtual intf vif;
	
	function new(string name ="tx_mon", uvm_component parent);
		super.new(name,parent);
	endfunction 

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		ap = new("ap", this);
		if(!uvm_config_db#(virtual intf) :: get(this, "", "vif", vif))
			`uvm_fatal("Monitor","Virtual interface not found")
	endfunction

	task run_phase(uvm_phase phase);
		tx_trans trans;
		bit_count = 0;
		transmission_started = 0;
		
		wait(!vif.rst);
		
		forever begin
			@(posedge vif.clk);
			
			if(vif.en) begin
				input_data = vif.data_in;
				input_en = vif.en;
				transmission_started = 0;
				bit_count = 0;
				collected_frame = 11'b0;
			end
			
			if(!transmission_started && vif.data_out == 1'b0) begin
				transmission_started = 1;
				bit_count = 0;
			end
			
			if( transmission_started) begin
				collected_frame[bit_count] = vif.data_out;
				bit_count++;
				if(bit_count == 11) begin
					trans = tx_trans :: type_id :: create ("trans");
					trans.en = input_en;
					trans.data_in = input_data;
					trans.data_out = vif.data_out;
					trans.data = collected_frame;
					ap.write(trans);
					transmission_started = 0;
					bit_count = 0;
				end
			end
		end
	endtask
endclass

////////////// Agent ////////

class tx_age extends uvm_agent;
	`uvm_component_utils(tx_age)
	tx_dri dri;
	tx_mon mon;
	tx_sequ sequ;
	virtual intf vif;
	
	function new(string name="tx_age", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual intf) :: get(this, "", "vif", vif))
			`uvm_fatal("agent","Virtual interface not found")
		
		mon = tx_mon :: type_id :: create("mon", this);
		mon.vif = vif;
		
		if(get_is_active() == UVM_ACTIVE) begin
			dri = tx_dri :: type_id :: create("dri", this);
			dri.vif = vif;
			sequ = tx_sequ :: type_id :: create("sequ", this);
		end
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		if(get_is_active() == UVM_ACTIVE) begin
			dri.seq_item_port.connect(sequ.seq_item_export);
		end
	endfunction
endclass

////////////// Scoreboard //////////
class tx_sb extends uvm_scoreboard;
	`uvm_component_utils(tx_sb)
	uvm_analysis_imp#(tx_trans, tx_sb) sb_imp;

	function new(string name="tx_sb", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sb_imp = new("sb_imp", this);
	endfunction

	function void write(tx_trans trans);
		logic [10:0] expected_frame;
		logic [10:0] actual_frame;
		logic expected_parity;
		
		expected_parity = ^trans.data_in;
		
		expected_frame = {1'b1, expected_parity, trans.data_in, 1'b0};
		actual_frame = trans.data;
		if (expected_frame == actual_frame) begin
			`uvm_info("SCOREBOARD", "PASS Frame matches expected pattern", UVM_LOW)
		end else begin
			`uvm_error("SCOREBOARD", $sformatf("FAIL Frame mismatch!\nExpected: %011b\nActual:   %011b\nInput data: 0x%0h", 
				expected_frame, actual_frame, trans.data_in))
		end
	endfunction
endclass

///////////// Environment //////////

class tx_env extends uvm_env;
	`uvm_component_utils(tx_env)
	tx_age age;
	tx_sb sb;
	
	function new(string name="tx_env", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		age = tx_age :: type_id :: create("age",this);
		sb = tx_sb :: type_id :: create("sb",this);
	endfunction
	
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		age.mon.ap.connect(sb.sb_imp);
	endfunction
endclass

/////////// Test //////////////

class tx_test extends uvm_test;
	`uvm_component_utils(tx_test)
	tx_env env;
	tx_seq seq;
	
	function new(string name="tx_test", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = tx_env :: type_id :: create("env",this);
		uvm_config_db#(uvm_active_passive_enum) :: set(null,"env.age","is_active",UVM_ACTIVE);
		seq = tx_seq :: type_id :: create("seq",this);
	endfunction
	
	task run_phase (uvm_phase phase);
		phase.raise_objection(this);
		seq.start(env.age.sequ);
		#1000; 
		phase.drop_objection(this);
	endtask
endclass

////// Top ///////////

module Verification_of_UART_TX();
	logic clk;
	logic rst;
	intf vif(clk,rst);
	
	uart_tx dut(.clk(clk),
		    .rst(rst),
		    .data_in(vif.data_in),
		    .en(vif.en),
		    .data_out(vif.data_out)); 
	
	always #5 clk = ~clk;
	
	initial begin
		clk = 0; 
		rst = 1;
		
		uvm_config_db#(virtual intf) :: set(null,"*","vif",vif);
		
		run_test("tx_test");
	end
	initial begin
		#10 rst = 0; 
	end
	
	initial begin
		#10000 $finish;
	end
endmodule