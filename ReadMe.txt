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
	  window_x = number,
	  window_y = number,
	}

If the string returns a value, it is displayed in the lower window frame
when the window is open.

Command: /rc
