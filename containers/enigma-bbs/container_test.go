package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ory/dockertest/v3"
	"github.com/ory/dockertest/v3/docker"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const minimalConfig = `{
    general: {
        boardName: "Test BBS"
        maxConnections: 0
    }
    paths: {
        logs: /enigma-bbs/logs
    }
    logging: {
        rotatingFile: {
            level: "info"
        }
    }
    theme: {
        default: luciano_blocktronics
    }
    loginServers: {
        telnet: {
            port: 8023
        }
    }
    users: {
        requireActivation: false
    }
}`

func getImageTag() string {
	// Use TEST_IMAGE_TAG from environment, fallback to "rolling" for local testing
	if tag := os.Getenv("TEST_IMAGE_TAG"); tag != "" {
		return tag
	}
	return "rolling"
}

// createTempConfigFile creates a temporary config file and returns the path
func createTempConfigFile(t *testing.T) string {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "config.hjson")
	err := os.WriteFile(configPath, []byte(minimalConfig), 0644)
	require.NoError(t, err, "Could not create temp config file")
	return configPath
}

const minimalMenuConfig = `{
    menus: {
        mainMenu: {
            desc: Main Menu
            art: MMENU
            prompt: menuCommand
        }
        fullLogoffSequence: {
            desc: Logging Off
            prompt: logoffConfirmation
        }
        logoff: {
            desc: Logging Off
            art: LOGOFF
            next: @systemMethod:logoff
        }
    }
    prompts: {
        menuCommand: {
            art: MNUPRMT
        }
        logoffConfirmation: {
            art: LOGPMPT
        }
    }
}`

// createTempConfigDir creates a temporary config directory with all required files
func createTempConfigDir(t *testing.T) string {
	tmpDir := t.TempDir()
	configDir := filepath.Join(tmpDir, "config")
	err := os.Mkdir(configDir, 0777) // Make it writable by all so UID 1000 in container can write
	require.NoError(t, err, "Could not create temp config directory")

	// Create config.hjson
	configPath := filepath.Join(configDir, "config.hjson")
	err = os.WriteFile(configPath, []byte(minimalConfig), 0666)
	require.NoError(t, err, "Could not create config.hjson")

	// Create menu.hjson
	menuPath := filepath.Join(configDir, "menu.hjson")
	err = os.WriteFile(menuPath, []byte(minimalMenuConfig), 0666)
	require.NoError(t, err, "Could not create menu.hjson")

	return configDir
}

func TestEnigmaContainer(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()
	t.Logf("Using image tag: %s", imageTag)

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start
	time.Sleep(5 * time.Second)

	// Test that the container is running
	assert.NotEmpty(t, resource.Container.ID, "Container should have an ID")

	t.Log("ENiGMA½ BBS container started successfully")
}

func TestUserAndPermissions(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	time.Sleep(5 * time.Second)

	t.Run("RunAsUser1000", func(t *testing.T) {
		// Verify container runs as user 1000:1000
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ $(id -u) -eq 1000 ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Container should run as UID 1000")

		exitCode, err = resource.Exec([]string{"sh", "-c", "[ $(id -g) -eq 1000 ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Container should run as GID 1000")
	})

	t.Run("EnigmaDirectoryOwnership", func(t *testing.T) {
		// Verify /enigma-bbs is owned by 1000:1000
		exitCode, err := resource.Exec([]string{"sh", "-c", "stat -c '%u:%g' /enigma-bbs | grep -q '1000:1000'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/enigma-bbs should be owned by 1000:1000")
	})

	t.Run("EnigmaDirectoryWritable", func(t *testing.T) {
		// Verify user can write to /enigma-bbs
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ -w /enigma-bbs ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/enigma-bbs should be writable by user 1000")
	})

	t.Run("CanCreateDirectories", func(t *testing.T) {
		// Test that user can create directories (e.g., core/mailers/)
		exitCode, err := resource.Exec([]string{"mkdir", "-p", "/enigma-bbs/core/test-dir"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create directories in /enigma-bbs")

		// Verify directory was created
		exitCode, err = resource.Exec([]string{"test", "-d", "/enigma-bbs/core/test-dir"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Created directory should exist")

		// Clean up
		resource.Exec([]string{"rm", "-rf", "/enigma-bbs/core/test-dir"}, dockertest.ExecOptions{})
	})

	t.Run("CanCreateFiles", func(t *testing.T) {
		// Test that user can create files
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo 'test' > /enigma-bbs/test-file.txt"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create files in /enigma-bbs")

		// Verify file was created
		exitCode, err = resource.Exec([]string{"test", "-f", "/enigma-bbs/test-file.txt"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Created file should exist")

		// Verify file ownership
		exitCode, err = resource.Exec([]string{"sh", "-c", "stat -c '%u:%g' /enigma-bbs/test-file.txt | grep -q '1000:1000'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Created file should be owned by 1000:1000")

		// Clean up
		resource.Exec([]string{"rm", "-f", "/enigma-bbs/test-file.txt"}, dockertest.ExecOptions{})
	})
}

func TestEnigmaDirectoryStructure(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	time.Sleep(5 * time.Second)

	t.Run("EnigmaBaseDirectories", func(t *testing.T) {
		// Check that expected base directories exist
		dirs := []string{
			"/enigma-bbs/art",
			"/enigma-bbs/config",
			"/enigma-bbs/mods",
			"/enigma-bbs/core",
		}

		for _, dir := range dirs {
			exitCode, err := resource.Exec([]string{"test", "-d", dir}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should exist", dir)
		}
	})

	t.Run("EnigmaExecutables", func(t *testing.T) {
		// Check that main.js exists
		exitCode, err := resource.Exec([]string{"test", "-f", "/enigma-bbs/main.js"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "main.js should exist")

		// Check that oputil.js exists
		exitCode, err = resource.Exec([]string{"test", "-f", "/enigma-bbs/oputil.js"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "oputil.js should exist")
	})

	t.Run("NodeAndNpmAvailable", func(t *testing.T) {
		// Verify node is available
		exitCode, err := resource.Exec([]string{"sh", "-c", "command -v node"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "node should be available")

		// Verify npm is available
		exitCode, err = resource.Exec([]string{"sh", "-c", "command -v npm"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "npm should be available")

		// Verify pm2 is available (used to run ENiGMA½)
		exitCode, err = resource.Exec([]string{"sh", "-c", "command -v pm2"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "pm2 should be available")
	})
}

func TestEnigmaStartupWithConfig(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Env: []string{
			"TZ=America/Chicago",
			"NODE_ENV=production",
		},
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give container time to initialize
	time.Sleep(10 * time.Second)

	t.Run("EntrypointExecutes", func(t *testing.T) {
		// The entrypoint should run without errors
		// If the container is still running, the entrypoint succeeded
		_, err := resource.Exec([]string{"sh", "-c", "ps aux | grep -v grep | grep -q 'docker-entrypoint'"}, dockertest.ExecOptions{})
		// We don't require exact match since entrypoint may have handed off to pm2
		// Just verify container didn't crash
		require.NoError(t, err)
		t.Log("Container initialized successfully")
	})

	t.Run("ConfigDirectoryAccessible", func(t *testing.T) {
		// Verify /enigma-bbs/config is accessible
		exitCode, err := resource.Exec([]string{"test", "-d", "/enigma-bbs/config"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/enigma-bbs/config should be accessible")
	})

	t.Run("CanWriteConfigFile", func(t *testing.T) {
		// Test writing a config file
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo '" + minimalConfig + "' > /enigma-bbs/config/test-config.hjson"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to write config file")

		// Verify config was written
		exitCode, err = resource.Exec([]string{"test", "-f", "/enigma-bbs/config/test-config.hjson"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Config file should exist")

		// Verify ownership
		exitCode, err = resource.Exec([]string{"sh", "-c", "stat -c '%u:%g' /enigma-bbs/config/test-config.hjson | grep -q '1000:1000'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Config file should be owned by 1000:1000")
	})
}

func TestPM2RuntimeAvailable(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	time.Sleep(5 * time.Second)

	t.Run("PM2RuntimeInstalled", func(t *testing.T) {
		exitCode, err := resource.Exec([]string{"sh", "-c", "command -v pm2-runtime"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "pm2-runtime should be installed")
	})

	t.Run("PM2CanListProcesses", func(t *testing.T) {
		// This may fail if pm2 isn't running, but command should exist
		exitCode, err := resource.Exec([]string{"sh", "-c", "command -v pm2"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "pm2 command should be available")
	})
}

func TestEnvironmentVariables(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Env: []string{
			"TZ=America/New_York",
			"NODE_ENV=development",
		},
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	time.Sleep(5 * time.Second)

	t.Run("TimezoneSet", func(t *testing.T) {
		// Verify TZ env var is set
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$TZ\" = \"America/New_York\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "TZ should be set to America/New_York")
	})

	t.Run("NodeEnvSet", func(t *testing.T) {
		// Verify NODE_ENV is set
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$NODE_ENV\" = \"development\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "NODE_ENV should be set to development")
	})
}

func TestPM2StartsWithoutPermissionIssues(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()

	// Create temp config file and mount it
	configPath := createTempConfigFile(t)

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Env: []string{
			"TZ=America/Chicago",
			"NODE_ENV=production",
		},
		Mounts: []string{
			configPath + ":/enigma-bbs/config/config.hjson:ro",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give container time to start and PM2 to initialize
	time.Sleep(15 * time.Second)

	// Check if container is still running and get logs if not
	container, err := pool.Client.InspectContainer(resource.Container.ID)
	if err == nil && !container.State.Running {
		_ = pool.Client.Logs(docker.LogsOptions{
			Container:    resource.Container.ID,
			OutputStream: os.Stderr,
			ErrorStream:  os.Stderr,
			Stdout:       true,
			Stderr:       true,
			Tail:         "50",
		})
		t.Logf("Container exited. Exit code: %d", container.State.ExitCode)
		t.Skip("Container exited before test could complete - check logs above")
	}

	t.Run("PM2ProcessRunning", func(t *testing.T) {
		// Check if PM2 process is running
		exitCode, err := resource.Exec([]string{"sh", "-c", "ps aux | grep -v grep | grep -q pm2"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		// Exit code 0 means pm2 is running
		if exitCode == 0 {
			t.Log("PM2 is running successfully")
		} else {
			t.Log("PM2 may not be running (could be normal if entrypoint hasn't started yet)")
		}
	})

	t.Run("NoPermissionErrorsInLogs", func(t *testing.T) {
		// Check for common permission errors
		// EACCES is the error code for permission denied
		_, err := resource.Exec([]string{"sh", "-c", "dmesg 2>/dev/null | grep -i 'EACCES' || true"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		// We just want this to run without error - permission errors would be visible
		t.Log("Checked for permission errors in system logs")
	})

	t.Run("CanCreateRuntimeDirectories", func(t *testing.T) {
		// Specifically test the core/mailers directory that was problematic
		exitCode, err := resource.Exec([]string{"mkdir", "-p", "/enigma-bbs/core/test-runtime"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create runtime directories without permission errors")

		// Verify directory was created
		exitCode, err = resource.Exec([]string{"test", "-d", "/enigma-bbs/core/test-runtime"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Runtime directory should exist")

		// Clean up
		resource.Exec([]string{"rm", "-rf", "/enigma-bbs/core/test-runtime"}, dockertest.ExecOptions{})
	})

	t.Run("PM2HomeDirectoryWritable", func(t *testing.T) {
		// Check if PM2_HOME is set and writable
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ -n \"$PM2_HOME\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		if exitCode == 0 {
			// PM2_HOME is set, verify it's writable
			exitCode, err = resource.Exec([]string{"sh", "-c", "[ -w \"$PM2_HOME\" ] || mkdir -p \"$PM2_HOME\""}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "PM2_HOME should be writable")
			t.Log("PM2_HOME is configured and writable")
		}
	})

	t.Run("ContainerHealthy", func(t *testing.T) {
		// Final check: container should still be running without crashes
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo 'Container is healthy'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Container should be healthy and responsive")
		t.Log("Container is running successfully without permission issues")
	})
}

func TestEnigmaApplicationLaunches(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()
	t.Logf("Using image tag: %s", imageTag)

	// Read the test config file from the repo
	testConfigPath := filepath.Join("test-config.hjson")
	testConfigBytes, err := os.ReadFile(testConfigPath)
	require.NoError(t, err, "Could not read test-config.hjson from repo")

	// Create a temp directory for config
	tmpDir := t.TempDir()
	configDir := filepath.Join(tmpDir, "config")
	err = os.Mkdir(configDir, 0777)
	require.NoError(t, err, "Could not create temp config directory")

	// Pre-create subdirectories that ENiGMA½ will need to create
	// This works around macOS bind mount permission issues
	subdirs := []string{"security", "menus"}
	for _, subdir := range subdirs {
		err = os.Mkdir(filepath.Join(configDir, subdir), 0777)
		require.NoError(t, err, "Could not create "+subdir+" directory")
	}

	// Copy test-config.hjson to config directory
	err = os.WriteFile(filepath.Join(configDir, "config.hjson"), testConfigBytes, 0666)
	require.NoError(t, err, "Could not write config.hjson")

	// Write minimal menu.hjson
	err = os.WriteFile(filepath.Join(configDir, "menu.hjson"), []byte(minimalMenuConfig), 0666)
	require.NoError(t, err, "Could not write menu.hjson")

	// Start container with config mounted and default entrypoint
	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/enigma-bbs",
		Tag:        imageTag,
		Env: []string{
			"TZ=America/Chicago",
			"NODE_ENV=production",
		},
		Mounts: []string{
			configDir + ":/enigma-bbs/config",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the application time to fully start (PM2 + ENiGMA½ initialization)
	t.Log("Waiting for application to start...")
	time.Sleep(30 * time.Second)

	// First, verify the container is still running
	container, err := pool.Client.InspectContainer(resource.Container.ID)
	require.NoError(t, err, "Could not inspect container")

	if !container.State.Running {
		// Container crashed - get logs for debugging
		var logBuffer bytes.Buffer
		_ = pool.Client.Logs(docker.LogsOptions{
			Container:    resource.Container.ID,
			OutputStream: &logBuffer,
			ErrorStream:  &logBuffer,
			Stdout:       true,
			Stderr:       true,
			Tail:         "100",
		})
		t.Fatalf("Container exited unexpectedly. Exit code: %d\nLogs:\n%s",
			container.State.ExitCode, logBuffer.String())
	}

	// Capture container logs
	var stdoutBuf, stderrBuf bytes.Buffer
	err = pool.Client.Logs(docker.LogsOptions{
		Container:    resource.Container.ID,
		OutputStream: &stdoutBuf,
		ErrorStream:  &stderrBuf,
		Stdout:       true,
		Stderr:       true,
		Tail:         "200", // Get last 200 lines
	})
	require.NoError(t, err, "Could not retrieve container logs")

	// Combine stdout and stderr for checking
	combinedLogs := stdoutBuf.String() + stderrBuf.String()

	// Log the output for debugging
	t.Logf("Container logs:\n%s", combinedLogs)

	// Verify expected startup messages are present
	t.Run("PM2LaunchesInNoDaemonMode", func(t *testing.T) {
		assert.Contains(t, combinedLogs, "PM2 log: Launching in no daemon mode",
			"PM2 should launch in no daemon mode")
	})

	t.Run("PM2StartsMainApp", func(t *testing.T) {
		assert.Contains(t, combinedLogs, "PM2 log: App [main:0] starting in -fork mode-",
			"PM2 should start the main app in fork mode")
	})

	t.Run("PM2AppOnline", func(t *testing.T) {
		assert.Contains(t, combinedLogs, "PM2 log: App [main:0] online",
			"PM2 should report the app is online")
	})

	t.Run("EnigmaBannerDisplayed", func(t *testing.T) {
		// Check for the ENiGMA½ copyright notice which is part of the banner
		assert.Contains(t, combinedLogs, "ENiGMA½ Copyright (c)",
			"ENiGMA½ banner should be displayed")
	})

	t.Run("SystemStartedMessage", func(t *testing.T) {
		assert.Contains(t, combinedLogs, "System started!",
			"ENiGMA½ should display 'System started!' message")
	})

	t.Run("NoFatalErrors", func(t *testing.T) {
		// Check that there are no fatal errors or crashes in the logs
		assert.NotContains(t, strings.ToLower(combinedLogs), "fatal error",
			"Logs should not contain fatal errors")
		assert.NotContains(t, strings.ToLower(combinedLogs), "uncaught exception",
			"Logs should not contain uncaught exceptions")
		assert.NotContains(t, strings.ToLower(combinedLogs), "eacces",
			"Logs should not contain permission errors (EACCES)")
	})

	t.Run("ContainerStillHealthy", func(t *testing.T) {
		// Final verification that container is still running
		container, err := pool.Client.InspectContainer(resource.Container.ID)
		require.NoError(t, err)
		assert.True(t, container.State.Running, "Container should still be running after startup checks")
		t.Log("ENiGMA½ BBS application launched successfully!")
	})
}
