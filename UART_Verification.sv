`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.08.2025 10:23:26
// Design Name: 
// Module Name: UART_Verification
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/////////interface module
interface intf(input logic clk, input logic rst);
    logic en;            
    logic [7:0] data_in;
    logic data_out;
    logic [7:0] data_out_rx;
    logic data_valid;
endinterface

////////// Transaction Module
class transaction;
    rand bit en;
    rand bit [7:0] data_in;
    bit data_out;
    bit [7:0] data_out_rx;
    bit data_valid;
    
    function display();
        $display("Data_in = %0d, en = %0d",data_in, en);
    endfunction
endclass

///////// generator module
class generator;
    mailbox gen2dri;
    transaction trans;
    int en_high_count = 10;
    int en_low_count = 10;
    function new(mailbox gen2dri);
        this.gen2dri = gen2dri;
    endfunction
    
    task run();
            repeat (20) begin
                trans = new();
                trans.randomize();
                trans.en = 1;
                gen2dri.put(trans);
                trans.display();
                
                // Next cycle, deassert en
                trans = new();
                trans.en = 0;
                trans.data_in = 0;
                gen2dri.put(trans);
                #150;
            end
    endtask
endclass

///////// driver module 
class driver;
    virtual intf vif;
    mailbox gen2dri;
    transaction trans;
    
    function new(virtual intf vif, mailbox gen2dri);
        this.vif = vif;
        this.gen2dri = gen2dri; 
    endfunction
    
    task run();
        forever begin
            @(posedge vif.clk);
            if(vif.rst) begin
                vif.en <= 0;
                vif.data_in <= 0;
            end else begin
                gen2dri.get(trans);
                trans.display();
                vif.en <= trans.en;
                vif.data_in <= trans.data_in;
            end 
        end
    endtask
endclass



/////// environment module
class env;
    virtual intf vif;
    mailbox gen2dri;
    generator gen;
    driver dri;
    
    function new(virtual intf vif);
        this.vif = vif;
        gen2dri = new();
        gen = new(gen2dri);
        dri = new(vif,gen2dri);
    endfunction
    
    task run();
        fork
            gen.run();
            dri.run();
        join_none
    endtask
endclass

///////// test module
class test;
    virtual intf vif;
    env e0;
    
    function new(virtual intf vif);
        this.vif = vif;
        e0 = new(vif);
    endfunction
    
    task run();
        e0.run();
    endtask
endclass

/////////top module
module UART_Verification(

    );
    
    reg clk;
    reg rst;
    
    test t0;
    
    intf vif(clk, rst);
    
    uart dut (.clk(clk),.rst(rst),.en(vif.en),.data_in(vif.data_in),.data_out(vif.data_out),.data_out_rx(vif.data_out_rx),.data_valid(vif.data_valid));
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0 ; rst=1;
        #10 rst = 0;
        
        t0 = new(vif);
        t0.run();
        
        #1000 $finish;
    end
endmodule
