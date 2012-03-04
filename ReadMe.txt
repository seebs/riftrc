The RiftRC addon is mostly a dev tool; the idea is that you can create
a set of script commands which will be run automatically at startup.  This
is analogous to .cshrc/.bashrc/etcetera.

Saved variables:
	RiftRC_riftrc = {
	  buffers = {
	    name = { 
	      autorun = true,
	      data = { string, string, ... }
	    },
	  },
	  trash = {
	    name = { string, string, ... },
	  }
	  window_x = number,
	  window_y = number,
	}

If you run code, and it returns a value, the value is displayed.  The
value from the 'riftrc' member (if any) is displayed at startup.

The right side of the window is a list of snippets.  Checkboxes control
run-at-startup.  Run-at-startup behavior is in pairs() order, which is
to say, nondeterministic.

You can't delete or rename 'riftrc'; you can delete or rename other
fields (use SAVE to apply the rename).  If you delete another field,
the lines of code are moved to the .trash component of the saved variable.
If you want to use this addon, I bet that's enough for you to recover
it.  :)

Command: /rc (no args as of yet, planning to add some later)
