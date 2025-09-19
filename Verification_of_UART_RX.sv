`include "uvm_macros.svh"
import uvm_pkg ::*;

////////// Interface //////////

interface intf (input logic clk, input logic rst);
	logic data_in;
	logic [7:0] data_out_rx;
	logic data_valid;
endinterface

///////// Transaction //////////

class rx_trans extends uvm_sequence_item();
	bit data_in;
	rand bit [7:0]in;
	logic [7:0] data_out_rx;
	logic data_valid;
	logic [7:0]data;
	function new(string name="rx_trans");
		super.new(name);
	endfunction
	
	`uvm_object_utils_begin(rx_trans)
		`uvm_field_int(data_in, UVM_ALL_ON)
		`uvm_field_int(data_out_rx, UVM_ALL_ON)
		`uvm_field_int(data_valid, UVM_ALL_ON)
	`uvm_object_utils_end
endclass

///////// Sequence ///////////

class rx_seq extends uvm_sequence;
	`uvm_object_utils(rx_seq)
	
	logic [7:0] parity;
	function new(string name="rx_seq");
		super.new(name);
	endfunction

	task body();
		rx_trans trans; 
		repeat(5) begin
			trans = rx_trans :: type_id :: create("trans");
			start_item(trans);
			assert (trans.randomize());
			finish_item(trans);
		end
	endtask
endclass

///////////// Sequencer ///////////

class rx_sequ extends uvm_sequencer#(rx_trans);
	`uvm_component_utils(rx_sequ)

	function new(string name ="rx_sequ", uvm_component parent);
		super.new(name,parent);
	endfunction
endclass

//////////// Driver /////////////

class rx_dri extends uvm_driver#(rx_trans);
	`uvm_component_utils(rx_dri)
	virtual intf vif;
	function new(string name="rx_dri", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual intf) :: get(this, "" , "vif",vif))
			`uvm_info("Driver","No virtual interfave",UVM_MEDIUM)
	endfunction

	task run_phase(uvm_phase phase);
 		bit parity = 0;
  		rx_trans trans;
  		vif.data_in <= 1'b1;
  		forever begin
    		wait(!vif.rst);
    		seq_item_port.get_next_item(trans);

    		parity = ^trans.in;

	        @(posedge vif.clk);
    		vif.data_in <= 1'b0;

    		for (int i = 0; i < 8; i++) begin
      		@(posedge vif.clk);
     		vif.data_in <= trans.in[i]; 
    		end

    		@(posedge vif.clk);
    		vif.data_in <= parity; 

    		@(posedge vif.clk);
    		vif.data_in <= 1'b1; 

    
    		@(posedge vif.clk);
    		vif.data_in <= 1'b1;

   		 seq_item_port.item_done();
  		end
	endtask
endclass

///////////// Monitor //////////

class rx_mon extends uvm_monitor;
	`uvm_component_utils(rx_mon)
	uvm_analysis_port#(rx_trans) ap;
	virtual intf vif;
	logic [7:0] input_data;
	function new(string name="rx_mon", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual intf) :: get(this, "" , "vif",vif))
			`uvm_info("Driver","No virtual interfave",UVM_MEDIUM)
		ap = new("ap",this);
	endfunction
	task run_phase (uvm_phase phase);
  	rx_trans trans;
  	logic [7:0] input_data_local;
  	forever begin
   	 wait(!vif.rst);
    	@(posedge vif.clk);

    	if (vif.data_in === 1'b0) begin
      	input_data_local = 8'h00;
      	for (int i = 0; i < 8; i++) begin
        @(posedge vif.clk); 
        input_data_local[i] = vif.data_in;
      	end

      	@(posedge vif.clk); 
      	@(posedge vif.clk); 
      	wait (vif.data_valid === 1'b1);
        trans = rx_trans :: type_id :: create ("trans");
      	trans.data_out_rx = vif.data_out_rx;
      	trans.data_valid  = vif.data_valid;
      	trans.data        = input_data_local;

      	ap.write(trans);
    	end
  	end
	endtask
endclass

//////////// Agent ///////////

class rx_age extends uvm_agent;
	`uvm_component_utils(rx_age)
	rx_dri dri;
	rx_mon mon;
	rx_sequ sequ;
	virtual intf vif;
	
	function new(string name="rx_age", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual intf) :: get(this, "", "vif", vif))
			`uvm_fatal("agent","Virtual interface not found")
		
		mon = rx_mon :: type_id :: create("mon", this);
		mon.vif = vif;
		
		if(get_is_active() == UVM_ACTIVE) begin
			dri = rx_dri :: type_id :: create("dri", this);
			dri.vif = vif;
			sequ = rx_sequ :: type_id :: create("sequ", this);
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

class rx_sb extends uvm_scoreboard;
	`uvm_component_utils(rx_sb)
	uvm_analysis_imp#(rx_trans, rx_sb) sb_imp;
	function new(string name="rx_sb", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		sb_imp = new("sb_imp",this);
	endfunction

	function void write(rx_trans trans);
		if(trans.data_valid) begin
			if(trans.data == trans.data_out_rx) 
				`uvm_info("SB",$sformatf("pass expected = %b, actual = %b", trans.data, trans.data_out_rx),UVM_MEDIUM)
			else
				`uvm_info("SB",$sformatf("fail expected = %b, actual = %b", trans.data, trans.data_out_rx),UVM_MEDIUM)
		end else 
			`uvm_info("SB",$sformatf("Valid was Zero", trans.data_valid),UVM_MEDIUM)	
	endfunction
endclass

///////////// Environment //////////

class rx_env extends uvm_env;
	`uvm_component_utils(rx_env)
	rx_age age;
	rx_sb sb;
	
	function new(string name="rx_env", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		age = rx_age :: type_id :: create("age",this);
		sb = rx_sb :: type_id :: create("sb",this);
	endfunction
	
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		age.mon.ap.connect(sb.sb_imp);
	endfunction
endclass

/////////// Test //////////////

class rx_test extends uvm_test;
	`uvm_component_utils(rx_test)
	rx_env env;
	rx_seq seq;
	
	function new(string name="rx_test", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env = rx_env :: type_id :: create("env",this);
		uvm_config_db#(uvm_active_passive_enum) :: set(null,"env.age","is_active",UVM_ACTIVE);
		seq = rx_seq :: type_id :: create("seq",this);
	endfunction
	
	task run_phase (uvm_phase phase);
		phase.raise_objection(this);
		seq.start(env.age.sequ);
		#100; 
		phase.drop_objection(this);
	endtask
endclass

////// Top ///////////

module Verification_of_UART_RX();
	logic clk;
	logic rst;
	intf vif(clk,rst);
	
	uart_rx dut(.clk(clk),
		    .rst(rst),
		    .data_in(vif.data_in),
		    .data_out_rx(vif.data_out_rx),
		    .data_valid(vif.data_valid)
		     ); 
	
	always #5 clk = ~clk;
	
	initial begin
		clk = 0; 
		rst = 1;
		
		uvm_config_db#(virtual intf) :: set(null,"*","vif",vif);
		
		run_test("rx_test");
	end
	initial begin
		#10 rst = 0; 
	end
	
endmodule
