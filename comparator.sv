//----------------------------------------------------------------------------
// COPYRIGHT (C) : ERICSSON  AB, Sweden
// The document(s) may be used  and/or copied only with the written
// permission from Ericsson AB  or in accordance with the terms and
// conditions  stipulated in the agreement/contract under which the
// document(s) have been supplied.
//----------------------------------------------------------------------------
// Mjolnir Item Comparators
// Generic stream comparators designed to compare items received
// from two or more separate sources (eg EXP/PREDICTED, ACT/DUT)
//----------------------------------------------------------------------------

`ifndef __dvu_comparator__
 `define __dvu_comparator__

// Generic Comparator
class dvu_comparator #(type T = uvm_sequence_item) extends uvm_component;
  `uvm_component_param_utils(dvu_comparator#(T))
      
  //------------------------------------------------------------
  // Ports  {{

  // Expected items imp's
  `uvm_analysis_imp_decl(_exp)
  uvm_analysis_imp_exp #(T, dvu_comparator#(T)) exp_imp;

  // Actual items imp
  `uvm_analysis_imp_decl(_act)
  uvm_analysis_imp_act #(T, dvu_comparator#(T)) act_imp;

  // }}

  //------------------------------------------------------------
  // Config  {{

  // Enable
  bit enable = 1;

  // Compare mode
  // Default in-order compare
  typedef enum { IN_ORDER, OUT_OF_ORDER } mode_e;
  mode_e mode = IN_ORDER;
  
  // Enable EOT queue empty check
  // By default all enabled
  bit empty_queue_chk_en[string];

  // Comparer policy
  uvm_comparer policy;

  //------------------------------------------------------------
  // Private / Local Data Members {{

  // Used queues
  // Default: EXP, ACT
  bit queues[string] = '{"EXP":1, "ACT":1};

  // Max size allowed for each queue
  // Default: unlimited
  int queue_max_size[string];

  // Stats
  int received_cnt[string], match_cnt, mismatch_cnt;

  // Item Queues
  T items_q[string][$];

  // }}

  //------------------------------------------------------------
  // Build & Run functions {{

  // Constructor
  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
    // Analisys imp's
    exp_imp = new("exp_imp", this);
    act_imp = new("act_imp", this);
    // Policy
    policy = new;
    policy.show_max = 0;
  endfunction: new

  // Build
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction: build_phase

  // Check
  virtual function void check_phase(uvm_phase phase);
    // Check queues empty
    foreach (items_q[qid]) begin
      bit q_chk_en = (!empty_queue_chk_en.exists(qid) || empty_queue_chk_en[qid]);
      if (q_chk_en && items_q[qid].size()) begin
        `uvm_info(get_name(), $sformatf("%s queue not empty: \n%s", qid, sprint_queue(qid)), UVM_NONE);
        `uvm_error(get_name(), $sformatf("[QUEUE_NOT_EMPTY] %s queue not empty at end of test!", qid))
      end
    end
  endfunction: check_phase

  // Report
  virtual function void report_phase(uvm_phase phase);
    int unmacth_cnt;
    foreach (items_q[qid])
      unmacth_cnt += items_q[qid].size();
    `uvm_info(get_name(), $sformatf("Summary: [ match: %0d, mismatch: %0d, unmatched: %p ]",
        match_cnt, mismatch_cnt, unmacth_cnt), UVM_NONE);
  endfunction: report_phase


  // }}

  //------------------------------------------------------------
  // Add, Compare & Check {{

  // Receive expected items (imp)
  virtual function void write_exp(T item);
    add_item("EXP", item);
  endfunction

  // Receive actual items (imp)
  virtual function void write_act(T item);
    add_item("ACT", item);
  endfunction

  // Add item to queue
  virtual function void add_item(string qid, T item);
    // Check if enabled
    if (!enable)
      return;
    // Debug
    `uvm_info(get_name(), $sformatf("[ADD][%s] %s", qid, sprint_item(item)), UVM_HIGH)
    // Check queue is valid
    if (!check_queue_valid(qid))
      return;
    // Check queue size
    if (queue_max_size.exists(qid)) begin
      if (items_q[qid].size() > queue_max_size[qid]) begin
        foreach (items_q[q])
          `uvm_info(get_name(), $sformatf("%s items: \n%s", q, sprint_queue(q)), UVM_NONE);
        `uvm_error(get_name(), $sformatf("Max queue size reached! (queue: %s, size: %0d)", 
          qid, queue_max_size[qid]));
      end
    end
    // Push to queue
    items_q[qid].push_back(item);
    received_cnt[qid] += 1;
    // Compare queues
    compare_queues(qid);
  endfunction

  // Compare items in specific queue
  virtual function void compare_queues(string qid);
    // Perform comparison based on the configured mode
    case (mode)
      IN_ORDER:     compare_in_order(qid);
      OUT_OF_ORDER: compare_out_of_order(qid);
    endcase
  endfunction

  // In-order comparison logic
  virtual function void compare_in_order(string qid);
    T exp_item, act_item;
    while (items_q["EXP"].size() && items_q["ACT"].size()) begin
      exp_item = items_q["EXP"].pop_front();
      act_item = items_q["ACT"].pop_front();
      compare_items(exp_item, act_item);
    end
  endfunction

  // Out-of-order comparison logic
  virtual function void compare_out_of_order(string qid);
    T exp_item, act_item;
    int idx[string];
    string cmp_q;
    bit match;
    // Received item will be the last in queue
    idx[qid] = items_q[qid].size()-1;
    // Search for a match in the other queue
    cmp_q = (qid == "EXP") ? "ACT" : "EXP";
    foreach (items_q[cmp_q][cmp_idx]) begin
      idx[cmp_q] = cmp_idx;
      match = do_compare_items(
        items_q["EXP"][idx["EXP"]],
        items_q["ACT"][idx["ACT"]]
      );
      if (match) begin
        // Save
        exp_item = items_q["EXP"][idx["EXP"]];
        act_item = items_q["ACT"][idx["ACT"]];
        // Delete
        items_q["EXP"].delete(idx["EXP"]);
        items_q["ACT"].delete(idx["ACT"]);
        // Compare
        compare_items(exp_item, act_item);
        // Done
        break;
      end
    end
  endfunction

  // Perform comparison check
  virtual function void compare_items(T exp_item, T act_item);
    bit match;
    // Pre-compare callback
    pre_compare_items(exp_item, act_item);
    // Compare items
    match = do_compare_items(exp_item, act_item);
    if (match) begin
      `uvm_info(get_name(), $sformatf("Item compare succeeded!\n  [EXP/ACT] %s",
          sprint_item(exp_item)), UVM_HIGH)
      match_cnt += 1;
    end
    else begin
      `uvm_warning(get_name(), $sformatf("Item compare failed! \n  [EXP] %s\n  [ACT] %s\n  [DIF]: %s",
          sprint_item(exp_item), sprint_item(act_item), policy.miscompares))
      `uvm_error(get_name(), $sformatf("Item compare failed!"));
      mismatch_cnt += 1;
    end
    // Post-compare callback
    post_compare_items(exp_item, act_item, match);
  endfunction

  // Pre compare call-back
  virtual function void pre_compare_items(T exp_item, T act_item);
  endfunction

  // Perform items compare
  virtual function bit do_compare_items(T exp_item, act_item);
    return exp_item.compare(act_item, policy);
  endfunction

  // Post compare call-back
  virtual function void post_compare_items(T exp_item, T act_item, bit match);
  endfunction
  
  //------------------------------------------------------------
  // Queue helpers {{
    
  // Set queues used
  virtual function void add_queues(string qs[]);
    foreach (qs[i]) queues[qs[i]] = 1;
  endfunction
  
  // Check queue valid
  virtual function bit check_queue_valid(string qid);
    if (!queues.exists(qid))
      `uvm_error(get_name(), $sformatf("Invalid queue (%s)", qid));
    return queues.exists(qid);
  endfunction
  
  // Set queues max size
  virtual function void set_queues_max_size(string qs[], int max_size);
    foreach (qs[i]) begin
      void'(check_queue_valid(qs[i]));
      queue_max_size[qs[i]] = max_size;
    end
  endfunction  
  
  // Reset queues
  virtual function void reset_queues(string qs[] = {});
    if (qs.size()) begin
      foreach (qs[i]) begin
        void'(check_queue_valid(qs[i]));
        items_q[i].delete();
      end      
    end else begin
      foreach (items_q[i])
        items_q[i].delete();
    end
  endfunction  

  // Converts queue to string
  virtual function string sprint_queue(string qid);
    string result;
    foreach (items_q[qid][i])
      result = {result, $sformatf("  [%s] %s\n", qid, sprint_item(items_q[qid][i]))};
    return result;
  endfunction

  //------------------------------------------------------------
  // Helpers {{

  // Converts item to string
  virtual function string sprint_item(T item);
    return item.sprint(uvm_default_line_printer);
  endfunction

  // }}

endclass

// Token Comparator
class dvu_token_comparator extends dvu_comparator #(er_token_base_token);
  `uvm_component_utils(dvu_token_comparator)
  
  // Enable UD check
  bit ud_check_en = 1;
  
  //------------------------------------------------------------
  // Functions / Overrides {{

  // Constructor
  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction: new

  // Perform items compare
  virtual function bit do_compare_items(T exp_item, act_item);
    bit result;
    // Do token compare
    result = exp_item.compare(act_item, policy);
    // Compare UD
    if (ud_check_en && (exp_item.metadata["ud"] != act_item.metadata["ud"]))
      result = 0;
    // Return cmp result
    return result;
  endfunction

  // Converts item to string
  virtual function string sprint_item(T item);
    string result;
    result = item.to_string();
    if (item.has_metadata("ud"))begin
      max_ud_type_t ud[];
      string ud_s;
      ud = { >>{item.get_metadata("ud")} };
      foreach (ud[i])
        ud_s = {ud_s, $sformatf(" 0x%0h", ud[i])};
      result = {result, $sformatf(" UD:[%s ]", ud_s)};
    end
    return result;
  endfunction
  
  // }} 
  
endclass

`endif
