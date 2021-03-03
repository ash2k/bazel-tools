package main

import (
	"context"
	"fmt"
	"io"
)

type multirun struct {
	commands               []command
	stdoutSink, stderrSink io.Writer
	args                   []string
	jobs                   int
	quiet                  bool
}

func (m multirun) run(ctx context.Context) error {
	// minimum concurrency is 1, which is sequential
	if m.jobs < 0 {
		return fmt.Errorf("jobs must be at least 0")
	}

	if m.jobs == 0 {
		return m.unboundedExecution(ctx)
	}

	return m.boundedExecution(ctx)
}

// unboundedExecution execute multiple commands without concurrency limit
func (m multirun) unboundedExecution(ctx context.Context) error {
	errs := make(chan error)

	for _, cmd := range m.commands {
		p := process{
			tag:        cmd.Tag,
			path:       cmd.Path,
			stdoutSink: m.stdoutSink,
			stderrSink: m.stderrSink,
			args:       m.args,
			addTag:     true,
		}

		go func() {
			errs <- p.run(ctx)
		}()
	}

	var firstError error
	for range m.commands {
		if err := <-errs; firstError == nil {
			firstError = err
		}
	}

	return firstError
}

// boundedExecution execute multiple commands using a sized worker pool
func (m multirun) boundedExecution(ctx context.Context) error {
	// errs should be buffered to avoid blocking
	// when len(m.commands) > m.jobs
	errs := make(chan error, len(m.commands))
	commands := make(chan command)

	// start worker pool
	for w := 0; w < m.jobs; w++ {
		go m.spawnWorker(ctx, commands, errs)
	}

	// send command to worker pool
	for _, cmd := range m.commands {
		commands <- cmd
	}
	close(commands)

	var firstError error
	for range m.commands {
		if err := <-errs; firstError == nil {
			firstError = err
		}
	}

	return firstError
}

func (m multirun) spawnWorker(ctx context.Context, commands <-chan command, errs chan<- error) {
	for cmd := range commands {
		p := process{
			tag:        cmd.Tag,
			path:       cmd.Path,
			stdoutSink: m.stdoutSink,
			stderrSink: m.stderrSink,
			args:       m.args,
		}

		// when execute concurrently, tag should be added
		if m.jobs > 1 {
			p.addTag = true
		}

		if !m.quiet {
			fmt.Fprintf(m.stderrSink, "Running %s\n", cmd.Tag)
		}

		errs <- p.run(ctx)
	}
}
