// Analisys import array macro
// Usage example:
// # Declare
//   `uvm_analysis_imp_array_decl(_rcv)
//   uvm_analysis_imp_array_rcv #(my_item, my_component) rcv_imp[NUM_PORTS];
//
// # Instantiate
//   function new(string name = "", uvm_component parent);
//     super.new(name, parent);
//     foreach (rcv_imp[i]) 
//       rcv_imp[i] = new($sformatf("rcv_imp[%0d]", i), this, i);
//   endfunction : new
//
// # Write
//  function void write_rcv(my_item item, int idx);
//    process_item(item);    
//  endfunction

`define uvm_analysis_imp_array_decl(SFX) \
class uvm_analysis_imp_array``SFX #(type T=int, type IMP=int) extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
  local IMP m_imp; \
  local int unsigned idx; \
  function new(string name, IMP imp, int unsigned idx); \
    super.new(name, imp, UVM_IMPLEMENTATION, 1, 1); \
    m_imp = imp; \
    this.idx = idx; \
    m_if_mask = `UVM_TLM_ANALYSIS_MASK; \
  endfunction \
  `UVM_TLM_GET_TYPE_NAME(`"uvm_analysis_imp_array``SFX`") \
  function void write( input T t); \
    m_imp.write``SFX(t, idx); \
  endfunction \
endclass
