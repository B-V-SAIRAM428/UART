`include "uvm_macros.svh"
import uvm_pkg :: *;

//////////// Interface ///////

interface intf (input logic clk, input logic rst);
	logic en;
	logic [7:0] data_in;
	logic [7:0] data_out_rx;
	logic data_valid;
endinterface

///////// Transaction ////////

class uart_trans extends uvm_sequence_item;
	rand logic en;
	rand logic [7:0] data_in;
	logic [7:0]data_out_rx;
	logic [7:0] data;
	logic data_valid;
	function new(string name = "uart_trans");
		super.new(name);
	endfunction 
	
	`uvm_object_utils_begin(uart_trans)
		`uvm_field_int(en,UVM_ALL_ON)
		`uvm_field_int(data_in,UVM_ALL_ON)
		`uvm_field_int(data_out_rx,UVM_ALL_ON)
	`uvm_object_utils_end
endclass

///////////// Sequence /////////

class uart_seq extends uvm_sequence;
	`uvm_object_utils(uart_seq)
	
	function new(string name ="uart_seq");
		super.new(name);
	endfunction 
	
	task body ();
		repeat(31) begin 
			uart_trans trans;
			trans = uart_trans :: type_id :: create("trans");
			start_item(trans);
			assert (trans.randomize() with {trans.en ==1;});
			finish_item(trans);
			
			#200;
		end
	endtask
endclass

////////// Sequencer ////////

class uart_sequ extends uvm_sequencer#(uart_trans);
	`uvm_component_utils(uart_sequ)
	
	function new(string name = "uart_sequ", uvm_component parent);
		super.new(name, parent);
	endfunction
endclass

///////// Driver ///////////

class uart_dri extends uvm_driver#(uart_trans);
	`uvm_component_utils(uart_dri)
	virtual intf vif;
	
	function new(string name ="uart_dri", uvm_component parent);
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
			uart_trans trans;
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

class uart_mon extends uvm_monitor;
	`uvm_component_utils(uart_mon)
	uvm_analysis_port#(uart_trans) ap;
	virtual intf vif;
	function new(string name="uart_mon", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual intf) :: get(this, "" , "vif",vif))
			`uvm_info("Driver","No virtual interfave",UVM_MEDIUM)
		ap = new("ap",this);
	endfunction
	task run_phase (uvm_phase phase);
  		uart_trans trans;
  		logic [7:0] input_data = 0;
		logic input_en =0;
  		forever begin
   			wait(!vif.rst);
			@(posedge vif.en);
			if(vif.en) begin
			input_data = vif.data_in;
			input_en = vif.en;
			end
			#100;
			@(posedge vif.clk);
      			wait (vif.data_valid === 1'b1);
        		trans = uart_trans :: type_id :: create ("trans");
      			trans.data_out_rx = vif.data_out_rx;
      			trans.data_valid  = vif.data_valid;
      			trans.data        = input_data;
			trans.en = input_en;
      			ap.write(trans);
    		end
	endtask
endclass


//////////// Agent ///////////

class uart_age extends uvm_agent;
	`uvm_component_utils(uart_age)
	uart_dri dri;
	uart_mon mon;
	uart_sequ sequ;
	virtual intf vif;
	
	function new(string name="uart_age", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual intf) :: get(this, "", "vif", vif))
			`uvm_fatal("agent","Virtual interface not found")
		
		mon = uart_mon :: type_id :: create("mon", this);
		mon.vif = vif;
		
		if(get_is_active() == UVM_ACTIVE) begin
			dri = uart_dri :: type_id :: create("dri", this);
			dri.vif = vif;
			sequ = uart_sequ :: type_id :: create("sequ", this);
		end
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		if(get_is_active() == UVM_ACTIVE) begin
			dri.seq_item_port.connect(sequ.seq_item_export);
		end
	endfunction
endclass

/////////////// Scoreboard //////////

class uart_sb extends uvm_scoreboard;
	`uvm_component_utils(uart_sb)
	uvm_analysis_imp#(uart_trans, uart_sb) sb_imp;
	logic [7:0] mem[$];
	logic [7:0] ex;
	function new(string name="uart_sb", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sb_imp = new("sb_imp",this);
	endfunction

	function void write(uart_trans trans);
		mem.push_front(trans.data);
		if(trans.data_valid) begin
			ex= mem.pop_back();
			if(ex == trans.data_out_rx) 
				`uvm_info("SB",$sformatf("pass expected = %b, actual = %b", trans.data, trans.data_out_rx),UVM_MEDIUM)
			else
				`uvm_info("SB",$sformatf("fail expected = %b, actual = %b", trans.data, trans.data_out_rx),UVM_MEDIUM)
		end else 
			`uvm_info("SB",$sformatf("Valid was Zero", trans.data_valid),UVM_MEDIUM)	
	endfunction
endclass

///////////// Environment //////////

class uart_env extends uvm_env;
	`uvm_component_utils(uart_env)
	uart_age age;
	uart_sb sb;
	
	function new(string name="uart_env", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		age = uart_age :: type_id :: create("age",this);
		sb = uart_sb :: type_id :: create("sb",this);
	endfunction
	
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		age.mon.ap.connect(sb.sb_imp);
	endfunction
endclass

/////////// Test //////////////

class uart_test extends uvm_test;
	`uvm_component_utils(uart_test)
	uart_env env;
	uart_seq seq;
	
	function new(string name="uart_test", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = uart_env :: type_id :: create("env",this);
		uvm_config_db#(uvm_active_passive_enum) :: set(null,"env.age","is_active",UVM_ACTIVE);
		seq = uart_seq :: type_id :: create("seq",this);
	endfunction
	
	task run_phase (uvm_phase phase);
		phase.raise_objection(this);
		seq.start(env.age.sequ);
		#100; 
		phase.drop_objection(this);
	endtask
endclass

////// Top ///////////

module Verification_of_UART();
	logic clk;
	logic rst;
	intf vif(clk,rst);
	
	uart dut(.clk(clk),
		    .rst(rst),
		    .en(vif.en),
		    .data_in(vif.data_in),
		    .data_out_rx(vif.data_out_rx),
		    .data_valid(vif.data_valid)
		     ); 
	
	always #5 clk = ~clk;
	
	initial begin
		clk = 0; 
		rst = 1;
		
		uvm_config_db#(virtual intf) :: set(null,"*","vif",vif);
		
		run_test("uart_test");
	end
	initial begin
		#10 rst = 0; 
	end
	
endmodule
