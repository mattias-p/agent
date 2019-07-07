# The Agent

I wrote this because I wanted to try out the principles laid out in [Clean
Architecture] by Robert C. Martin.

## Behavior

In short the agent is a daemon that allocates jobs and spawns a worker process
for them.

It kills overdue workers, releases unfinished jobs, reloads its configuration
file gracefully and shuts down gracefully or hard.
It is also able to guarantee failure of certain operations a certain percentage
of the time - for testing purposes.

The current implementations of the configuration file is just a dummy.
The the work carried out by the workers is also just make-believe - they
simply sleep for a random number of seconds.

The agent has a number of phases: initialization, active, graceful shutdown,
hard shutdown and a final phase.

### The Initialization phase

In the initialization phase the agent loads its configuration file, starts
logging and daemonizes itself.
If any of these fail the agent prints an error message and terminates.
Otherwise it enters the active phase.

### The Active phase

In the active phase the agent allocates jobs and spawns workers for them.
If there are no more jobs to be allocated, the agent goes to sleep waiting for
signals.
For every worker it spawned it also initialtes a timeout that will result in a
SIGALRM back to itself.

On SIGALRM the agent sends SIGKILL to all workers that are overdue.
On SIGCHLD the agent reaps all terminated workers.
It also releases their associated jobs in case they haven't done so themselves.
On SIGHUP the agent wakes up and reloads its configuration file.
If the file cannot be loaded or if it is invalid, the agent keeps its old
configuration.
On SIGUSR2 the agent wakes up and looks for more work as described above.
On SIGTERM the agent enters the graceful shutdown phase.

For resource management reasons, the agent prioritizes handling new signals over
spawning more workers.
However once the agent has handled the signal it doesn't remember whether or not
it was in the middle of spawning workers.
To be on the safe, it follows up on SIGALRM, SIGCHLD and SIGHUP with checking
for more work as described above.

### The Graceful Shutdown phase

In the graceful shutdown phase the agent allows active workers to complete their
work but doesn't spawn any new ones.

In essence the agent operates just like in the active phase, but with the
following exceptions:

1. The agent won't look for more work and consequently it doesn't spawn any new
   workers.
2. The agent won't try to reload its configuration file.
3. As soon as there are no active workers the agent enters the final phase.
4. On SIGTERM the agent enters the hard shutdown phase.

### The Hard Shutdown phase

In the hard shutdown phase the agent immediately send SIGKILL to all of its
active workers, reaps them and releases their associated jobs, and enters the
final phase.

### The final phase

In the final phase the agent simply terminates with exit status 0.

## Design

TBD

## Known problems

* The implementation should be documented in order to identify weaknesses in the
  design.

* The implementation should be tested according to the documentation in order to
  identify weaknesses in the documentation.

* The logging is getting verbose.
  There should be some filtering.

* Getting weird behaviors invoking `confess "derp"`.
  During some executions of `example.pl`, calls to `confess "derp"` work as
  expected.
  During some executions, the same calls consistently generate messages like
  this:

      [Fri Jul  5 20:02:46 2019] job(1172:13947) threw exception: panic: attempt to copy freed scalar 559fbcc2fe78 to 559fbce580f8 at /usr/share/perl/5.24/Carp.pm line 229.

  During some executions, but more seldom, the same calls consistently generate
  messages like this:

      [Fri Jul  5 20:05:37 2019] job(1179:13997) threw exception: Bizarre copy of HASH in list assignment at /usr/share/perl/5.24/Carp.pm line 229.


[Clean Architecture]: https://www.goodreads.com/book/show/18043011-clean-architecture
