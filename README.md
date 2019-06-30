# About

I wrote this because I wanted to try out the principles laid out in [Clean
Architecture] by Robert C. Martin.

It's an agent whose default mode is to block waiting for signals telling it what
to do.

 * On startup it load a config file.
 * On SIGHUP it reloads its config and goes back to sleep.
 * On SIGUSR1 it looks for work to do and goes back to sleep.
 * On the first SIGTERM it goes into graceful shutdown.
 * On the second SIGTERM it goes into hard shutdown.

The loading of the config file is currently just make-believe.
The is no such file.
Instead the loading will report success some percentage of the time and failure
some percentage.

When looking for work the agent attempts to allocate a job id, spawn a worker
process for it, and set the worker to work.
If the job id allocation was successful, it won't go back to sleep immediately,
but instead look for more work.
When there are no more jobs to allocate, the agent will go back to sleep.

The job id allocation is currently just make-believe.
There are no real jobs.
Instead the allocation will report success (with a job id by incrementing a
counter) some percentage of the time and failure some percentage.

Spawning new processes can fail but in practice it rarely does.
To facilitate testing of related code paths, syntetic failures have been
implemented to emulate failed spawning of worker processes.
Some percentage of the time it will report failure without even trying.

The work performed by the workers is also make-believe.
They just sleep for a variable amount of time.
When they're done they release the job id and terminate.

If the workers take too long with a job, the agent kills them and releases the
associated job id.
The current implementation isn't entirely robust.
External processes can interfere by sending SIGALRM to the agent causing workers
to be killed prematurely.

In the shutdown states the agent doesn't react to SIGHUP and SIGUSR1 anymore.


[Clean Architecture]: https://www.goodreads.com/book/show/18043011-clean-architecture
