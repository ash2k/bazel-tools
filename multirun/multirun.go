package main

import (
	"context"
	"fmt"
	"io"
	"sync"
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
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
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
		err := <-errs
		if err != nil && firstError == nil {
			cancel()
			firstError = err
		}
	}

	return firstError
}

// boundedExecution execute multiple commands using a sized worker pool
func (m multirun) boundedExecution(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	// errs should be buffered to avoid blocking
	// when len(m.commands) > m.jobs
	errs := make(chan error, len(m.commands))
	commands := make(chan command, len(m.commands))

	// send command to worker pool
	for _, cmd := range m.commands {
		commands <- cmd
	}
	close(commands)

	// start worker pool
	var wg sync.WaitGroup
	wg.Add(m.jobs)
	for w := 0; w < m.jobs; w++ {
		go func() {
			defer wg.Done()
			err := m.spawnWorker(ctx, commands)
			if err != nil {
				errs <- err // first error must go first, cancel after it has been sent.
				cancel()
			}
		}()
	}

	wg.Wait()
	close(errs)

	for err := range errs {
		return err
	}

	return nil
}

func (m multirun) spawnWorker(ctx context.Context, commands <-chan command) error {
	for cmd := range commands {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
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

		err := p.run(ctx)
		if err != nil {
			return err
		}
	}
	return nil
}
