The RiftRC addon is mostly a dev tool; the idea is that you can create
a set of script commands which will be run automatically at startup.  This
is analogous to .cshrc/.bashrc/etcetera.

Saved variables:
	RiftRC_riftrc = {
	  riftrc = { string, string, ... },
	  scratch = { string, string, ... },
	  window_x = number,
	  window_y = number,
	}

The "riftrc" string will be loaded automatically, and executed automatically.

The "scratch" string is loaded automatically, but not executed automatically.

Command: /riftrc
