# About

I wrote this because I wanted to try out the principles lined out in "Clean
architecture" by Robert C. Martin.

It's an agent whose default mode is to block waiting for signals telling it what
to do.
On startup it pretends to load a config file.
On SIGHUP it pretends to reload its config.
On SIGUSR1 it pretends to allocate jobs from some database that doesn't
exist.
For each allocated job it spawns a real worker process.
The worker process pretends to work on its job for a while before releasing it
and terminating.
On SIGTERM the agent goes into graceful shutdown where it waits for all active
worker processes to complete on their own before terminating.
On a second SIGTERM the agent immediately kills off its active workers and
releases their job allocations before terminating.
If a worker takes to long with a job, the agent kills it and releases the job
allocation.
