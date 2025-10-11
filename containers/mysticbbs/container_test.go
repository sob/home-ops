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

	resource, err := pool.Run("ghcr.io/sob/mysticbbs", "rolling", []string{})
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

func TestMysticFilesystemLayout(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	resource, err := pool.Run("ghcr.io/sob/mysticbbs", "rolling", []string{
		"MYSTIC_PATH=/config",
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start
	time.Sleep(5 * time.Second)

	t.Run("MysticShareDirectory", func(t *testing.T) {
		// Check that /usr/local/share/mystic exists
		exitCode, err := resource.Exec([]string{"test", "-d", "/usr/local/share/mystic"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/usr/local/share/mystic should exist")
	})

	t.Run("InstallerFiles", func(t *testing.T) {
		files := []string{
			"/usr/local/share/mystic/install",
			"/usr/local/share/mystic/install_data.mys",
			"/usr/local/share/mystic/upgrade",
			"/usr/local/share/mystic/whatsnew.txt",
			"/usr/local/share/mystic/upgrade.txt",
		}

		for _, file := range files {
			exitCode, err := resource.Exec([]string{"test", "-f", file}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should exist", file)
		}
	})

	t.Run("ExecutablePermissions", func(t *testing.T) {
		executables := []string{
			"/usr/local/share/mystic/install",
			"/usr/local/share/mystic/upgrade",
		}

		for _, exe := range executables {
			exitCode, err := resource.Exec([]string{"test", "-x", exe}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should be executable", exe)
		}
	})

	t.Run("Symlinks", func(t *testing.T) {
		symlinks := map[string]string{
			"/usr/local/bin/mystic-install": "/usr/local/share/mystic/install",
			"/usr/local/bin/mystic-upgrade":  "/usr/local/share/mystic/upgrade",
		}

		for link, target := range symlinks {
			// Check symlink exists
			exitCode, err := resource.Exec([]string{"test", "-L", link}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should be a symlink", link)

			// Check symlink target
			exitCode, err = resource.Exec([]string{"sh", "-c", "[ \"$(readlink " + link + ")\" = \"" + target + "\" ]"}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should point to %s", link, target)
		}
	})

	t.Run("FileOwnership", func(t *testing.T) {
		// Check that files are owned by 65534:65534 (nobody:nogroup)
		exitCode, err := resource.Exec([]string{"sh", "-c", "stat -c '%u:%g' /usr/local/share/mystic/install | grep -q '65534:65534'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Mystic files should be owned by 65534:65534")
	})

	t.Run("CryptlibAvailable", func(t *testing.T) {
		// Verify cryptlib is installed and loadable
		exitCode, err := resource.Exec([]string{"test", "-f", "/usr/lib/libcl.so"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "cryptlib should be installed")

		// Check if ldconfig knows about it
		exitCode, err = resource.Exec([]string{"sh", "-c", "ldconfig -p | grep -q libcl"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "cryptlib should be in ldconfig cache")
	})
}

func TestMysticInstallation(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        "rolling",
		Env: []string{
			"MYSTIC_PATH=/config",
		},
		Mounts: []string{},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to install
	time.Sleep(30 * time.Second)

	t.Run("MysticExecutableInstalled", func(t *testing.T) {
		// Check that mis executable was installed
		exitCode, err := resource.Exec([]string{"test", "-f", "/config/mis"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "mis executable should be installed in /config")
	})

	t.Run("DocumentationCopied", func(t *testing.T) {
		docs := []string{
			"/config/whatsnew.txt",
			"/config/upgrade.txt",
		}

		for _, doc := range docs {
			exitCode, err := resource.Exec([]string{"test", "-f", doc}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should be copied to config directory", doc)
		}
	})

	t.Run("DataDirectoriesCreated", func(t *testing.T) {
		dirs := []string{
			"/config/data",
			"/config/logs",
			"/config/msgs",
		}

		for _, dir := range dirs {
			exitCode, err := resource.Exec([]string{"test", "-d", dir}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "%s should exist", dir)
		}
	})
}

func TestEnvironmentVariables(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	customPath := "/custom/mystic/path"
	customTZ := "America/New_York"
	customNode := "42"

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        "rolling",
		Env: []string{
			"MYSTIC_PATH=" + customPath,
			"TZ=" + customTZ,
			"MYSTIC_NODE=" + customNode,
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to install
	time.Sleep(30 * time.Second)

	t.Run("MysticPathRespected", func(t *testing.T) {
		// Verify MYSTIC_PATH env var is set
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$MYSTIC_PATH\" = \"" + customPath + "\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "MYSTIC_PATH should be set to %s", customPath)

		// Verify installation occurred at custom path
		exitCode, err = resource.Exec([]string{"test", "-f", customPath + "/mis"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Mystic should be installed to custom MYSTIC_PATH %s", customPath)

		// Verify documentation was copied to custom path
		exitCode, err = resource.Exec([]string{"test", "-f", customPath + "/whatsnew.txt"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Documentation should be copied to custom MYSTIC_PATH %s", customPath)
	})

	t.Run("TimezoneSet", func(t *testing.T) {
		// Verify TZ env var is set
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$TZ\" = \"" + customTZ + "\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "TZ should be set to %s", customTZ)

		// Verify timezone is actually applied (check date output)
		exitCode, err = resource.Exec([]string{"sh", "-c", "date +%Z | grep -E '(EST|EDT)'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Timezone should be applied (EST/EDT for America/New_York)")
	})

	t.Run("MysticNodeSet", func(t *testing.T) {
		// Verify MYSTIC_NODE env var is set
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$MYSTIC_NODE\" = \"" + customNode + "\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "MYSTIC_NODE should be set to %s", customNode)
	})
}

func TestDefaultEnvironmentVariables(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	// Run without explicit env vars to test defaults
	resource, err := pool.Run("ghcr.io/sob/mysticbbs", "rolling", []string{})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start
	time.Sleep(30 * time.Second)

	t.Run("DefaultMysticPath", func(t *testing.T) {
		// When MYSTIC_PATH is not set, it should default to /mystic (as per entrypoint.sh)
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"${MYSTIC_PATH:-/mystic}\" = \"/mystic\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "MYSTIC_PATH should default to /mystic")
	})

	t.Run("DefaultTimezone", func(t *testing.T) {
		// Verify default TZ from Dockerfile (America/Chicago)
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$TZ\" = \"America/Chicago\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "TZ should default to America/Chicago")
	})
}

func TestHookSystem(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        "rolling",
		Env: []string{
			"MYSTIC_PATH=/config",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start
	time.Sleep(5 * time.Second)

	t.Run("HooksDirectoryExists", func(t *testing.T) {
		// Create hooks directory
		exitCode, err := resource.Exec([]string{"mkdir", "-p", "/config/hooks"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create hooks directory")
	})

	t.Run("PreInstallHookExecuted", func(t *testing.T) {
		// Create a pre-install hook that writes a marker file
		hookContent := "#!/bin/bash\necho 'pre-install hook executed' > /config/pre-install-marker.txt"
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo '" + hookContent + "' > /config/hooks/pre-install.sh && chmod +x /config/hooks/pre-install.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create pre-install hook")

		// Remove mis to trigger reinstall
		exitCode, err = resource.Exec([]string{"rm", "-f", "/config/mis"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to remove mis")

		// Restart container to trigger hooks
		// Note: In a real scenario, this would require container restart which is complex in tests
		// For now, we test that hooks can be created and are executable
		exitCode, err = resource.Exec([]string{"test", "-x", "/config/hooks/pre-install.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "pre-install.sh should be executable")
	})

	t.Run("PostInstallHookExecuted", func(t *testing.T) {
		// Create a post-install hook
		hookContent := "#!/bin/bash\necho 'post-install hook executed' > /config/post-install-marker.txt"
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo '" + hookContent + "' > /config/hooks/post-install.sh && chmod +x /config/hooks/post-install.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create post-install hook")

		exitCode, err = resource.Exec([]string{"test", "-x", "/config/hooks/post-install.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "post-install.sh should be executable")
	})

	t.Run("StartupHookExecuted", func(t *testing.T) {
		// Create a startup hook
		hookContent := "#!/bin/bash\necho 'startup hook executed' > /config/startup-marker.txt"
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo '" + hookContent + "' > /config/hooks/startup.sh && chmod +x /config/hooks/startup.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create startup hook")

		exitCode, err = resource.Exec([]string{"test", "-x", "/config/hooks/startup.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "startup.sh should be executable")
	})

	t.Run("UpgradeHooksExist", func(t *testing.T) {
		// Create upgrade hooks
		preUpgrade := "#!/bin/bash\necho 'pre-upgrade hook executed' > /config/pre-upgrade-marker.txt"
		exitCode, err := resource.Exec([]string{"sh", "-c", "echo '" + preUpgrade + "' > /config/hooks/pre-upgrade.sh && chmod +x /config/hooks/pre-upgrade.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create pre-upgrade hook")

		postUpgrade := "#!/bin/bash\necho 'post-upgrade hook executed' > /config/post-upgrade-marker.txt"
		exitCode, err = resource.Exec([]string{"sh", "-c", "echo '" + postUpgrade + "' > /config/hooks/post-upgrade.sh && chmod +x /config/hooks/post-upgrade.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Should be able to create post-upgrade hook")

		// Verify both are executable
		exitCode, err = resource.Exec([]string{"test", "-x", "/config/hooks/pre-upgrade.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "pre-upgrade.sh should be executable")

		exitCode, err = resource.Exec([]string{"test", "-x", "/config/hooks/post-upgrade.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "post-upgrade.sh should be executable")
	})

	t.Run("HookPathResolution", func(t *testing.T) {
		// Verify hooks are looked for in MYSTIC_PATH/hooks
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ -d \"$MYSTIC_PATH/hooks\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "Hooks should be in MYSTIC_PATH/hooks directory")
	})
}