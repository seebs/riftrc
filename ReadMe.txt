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

1.8 and later only:

Now with messaging support!  You can send code snippets to other players or
receive code snippets from them.  Works only if both parties are using RiftRC
or something which sends the same sorts of snippets.

If you are not *already* cringing in terror at this feature, NEVER ENABLE IT.
This is dangerous.  It can be used maliciously.  It is risky.  DO NOT USE
THIS FEATURE.  Video depicts experienced programmers working on two laptops
on PTS shards using whitelisting.  NO REALLY STOP DO NOT DO THIS.  But it's
there if you really, really, know what you're doing.  NOT enabled by default.

Command: /rc
	/rc		Open editor window
	/rc -e name	Open editor window, switch to named buffer
	/rc [names]	Run the selected names
	/rc -r -e name	Open editor window, switch to named buffer, run it
	/rc -l		Live mode:  Refresh output every tick.
	/rc -m		Enable messaging support.
	/rc -w name	Whitelist name.  If any names are whitelisted,
			only messages from whitelisted users are accepted.
	/rc -b name	Blacklist name.
