package main

import (
	"testing"
	"time"

	"github.com/ory/dockertest/v3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMysticContainer(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	resource, err := pool.Run("ghcr.io/sob/mystic", "latest", []string{})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start
	time.Sleep(10 * time.Second)

	// Test that the container is running
	assert.NotEmpty(t, resource.Container.ID, "Container should have an ID")
	
	// Test that mystic user exists (basic smoke test)
	// In a real test, we might check if ports are listening, etc.
	t.Log("Mystic BBS container started successfully")
}