//------------------------------------------------------------------------------
// COPYRIGHT (c) Ericsson AB, 2020
// The copyright to the document(s) herein is the property of Ericsson AB.
// The document(s) may be used and/or copied only with the written permission
// from Ericsson AB, or in accordance with the terms and conditions stipulated
// in the agreement/contract under which the document(s) have been supplied.
// All rights reserved.
//------------------------------------------------------------------------------
// Report catcher
// Adds new error handling capabilities
//------------------------------------------------------------------------------

`ifndef __mjr_report_catcher__
`define __mjr_report_catcher__

// Report catcher 
// Usage  : 
//   my_rpc = new();
//   uvm_report_cb::add(path, my_rpc);
//   my_rpc.add_modifier(
//     .id("uid"), .severity(UVM_ERROR), .message_id("some msg id"), .message("some msg"),
//     .modify_severity(1), .new_severity(UVM_INFO),
//     .modify_verbosity(1), .new_verbosity(UVM_LOW));
class mjr_report_catcher extends uvm_report_catcher;
  `uvm_object_utils(mjr_report_catcher)
  
  // Define modifier params
  typedef struct {
    uvm_severity  severity;
    string        message_id;
    string        message;
    bit           modify_severity;
    uvm_severity  new_severity;
    bit           modify_verbosity;
    int           new_verbosity;
    bit           modify_action;
    uvm_action    new_action;
    bit           stacktrace;
    int           max_cnt;
    int           curr_cnt;
  } modifier_s;

  // Active modifiers list
  modifier_s mods[string];
  
  //------------------------------------------------------------
  // Implementation  {{

  // Constructor
  function new(string name="njd_report_catcher");
    super.new(name);
  endfunction

  // Catch callback implementation:
  // Will check is message match any of configured rules and
  // update it accordingly
  function action_e catch();
    //`uvm_info(get_name(), $sformatf("[DBG] Catched %s %s %s) ", get_severity(), get_id(), get_message()), UVM_DEBUG)
    foreach(mods[i]) begin
      if (mods[i].severity == get_severity()) begin
        // Debug
        //`uvm_info(get_name(), $sformatf("[DBG] Severity match (mods: %s, msg: %s) ", mods[i].severity, get_severity()), UVM_DEBUG)
        //if (!(mods[i].message_id != "" && uvm_re_match(mods[i].message_id , get_id())))
        //  `uvm_info(get_name(), $sformatf("[DBG] Message id match (mods: %s, msg: %s) ", mods[i].message_id, get_id()), UVM_DEBUG)
        //if (!(mods[i].message != "" && uvm_re_match(mods[i].message , get_message())))
        //  `uvm_info(get_name(), $sformatf("[DBG] Message match (mods: %s, msg: %s) ", mods[i].message, get_message()), UVM_DEBUG)        
        //if (!(mods[i].max_cnt > 0 && mods[i].max_cnt >= mods[i].curr_cnt ))
        //  `uvm_info(get_name(), $sformatf("[DBG] Message max cnt ok (mods: %d, curr: %d) ", mods[i].max_cnt, mods[i].curr_cnt ), UVM_DEBUG) 

        // Check match
        if ((mods[i].message_id != "" && uvm_re_match(mods[i].message_id , get_id())) ||
            (mods[i].message != "" && uvm_re_match(mods[i].message , get_message())) ||
            (mods[i].max_cnt > 0 && mods[i].max_cnt >= mods[i].curr_cnt )) begin
          continue;
        end

        // Update
        if (mods[i].modify_severity)
          set_severity(mods[i].new_severity);
        if (mods[i].modify_verbosity)
          set_verbosity(mods[i].new_verbosity);    
        if (mods[i].modify_action)
          set_action(mods[i].new_action);
        mods[i].curr_cnt += 1;
        
        // Extra
        if (mods[i].stacktrace)
          $stacktrace;
      end
    end
    return THROW;
  endfunction

  // }}

  //------------------------------------------------------------
  // API {{

  // Add catcher modifier
  virtual function void add_modifier(
      string id, uvm_severity severity = UVM_ERROR, string message_id = "", string message = "",
      bit modify_severity = 0,  uvm_severity  new_severity = UVM_INFO,
      bit modify_verbosity = 0, int           new_verbosity = UVM_MEDIUM,
      bit modify_action = 0,    uvm_action    new_action =  UVM_DISPLAY,
      bit stacktrace = 0,
      int max_cnt = -1);

    // Local vars
    modifier_s mod;

    // Sanitize inputs
    if (id=="")
      `uvm_error(get_name(), $sformatf("Id not set! Please provide a valid id!"))

    // Add catcher cfg to list
    mod.severity = severity;
    mod.message_id = message_id;
    mod.message = message;
    mod.modify_severity = modify_severity;
    mod.new_severity = new_severity;
    mod.modify_verbosity = modify_verbosity;
    mod.new_verbosity = new_verbosity;
    mod.modify_action = modify_action;
    mod.new_action = new_action;
    mod.stacktrace = stacktrace;
    mod.max_cnt = max_cnt;
    mods[id] = mod;
  endfunction

  // Remove catcher modifier
  virtual function void remove_modifier(string id);
    // Sanitize inputs
    if (mods.exists(id))
      mods.delete(id);
    else
      `uvm_warning(get_name(), $sformatf("No modifier found with this id!"))
  endfunction
  
  // }}
endclass

`endif
