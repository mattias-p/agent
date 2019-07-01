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

The current implementations of the configuration file and the source of jobs are
just dummies.
Consequently the jobs performed by the workers are also just make-believe - they
simply sleep for a random number of seconds.

The agent has a number of high-level states: initialization, active, graceful
shutdown, hard shutdown and a final state.

### The Initialization state

In the initialization high-level state the agent loads its configuration file,
starts logging and daemonizes itself.
If any of these fail the agent prints an error message and terminates.
Otherwise it enters the active high-level state.

### The Active state

In the active high-level state the agent allocates jobs and spawns workers for
them.
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
On SIGTERM the agent enters the graceful shutdown high-level state.

For resource management reasons, the agent prioritizes handling new signals over
spawning more workers.
However once the agent has handled the signal it doesn't remember whether or not
it was in the middle of spawning workers.
To be on the safe, it follows up on SIGALRM, SIGCHLD and SIGHUP with checking
for more work as described above.

### The Graceful Shutdown state

In the graceful shutdown high-level state the agent allows active workers to
complete their work but doesn't spawn any new ones.

In essence the agent operates just like in the active state, but with the
following exceptions:

1. The agent won't look for more work and consequently it doesn't spawn any new
   workers.
2. The agent won't try to reload its configuration file.
3. As soon as there are no active workers the agent enters the final state.
4. On SIGTERM the agent enters the hard shutdown state.

### The Hard Shutdown state

In the hard shutdown high-level state the agent immediately send SIGKILL to all
of its active workers, reaps them and releases their associated jobs, and enters
the final state.

### The final state

In the final state the agent terminates with exit status 0;

## Design


[Clean Architecture]: https://www.goodreads.com/book/show/18043011-clean-architecture
