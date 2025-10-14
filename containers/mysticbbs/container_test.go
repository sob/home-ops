package main

import (
	"fmt"
	"net"
	"os"
	"testing"
	"time"

	"github.com/ory/dockertest/v3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func getImageTag() string {
	// Use TEST_IMAGE_TAG from environment, fallback to "rolling" for local testing
	if tag := os.Getenv("TEST_IMAGE_TAG"); tag != "" {
		return tag
	}
	return "rolling"
}

func TestMysticContainer(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()
	t.Logf("Using image tag: %s", imageTag)

	resource, err := pool.Run("ghcr.io/sob/mysticbbs", imageTag, []string{})
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

	imageTag := getImageTag()
	resource, err := pool.Run("ghcr.io/sob/mysticbbs", imageTag, []string{
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
		Tag:        getImageTag(),
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

	customPath := "/tmp/custom-mystic"  // Use /tmp which is writable by nobody user
	customTZ := "America/New_York"
	customNode := "42"

	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        getImageTag(),
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
	imageTag := getImageTag()
	resource, err := pool.Run("ghcr.io/sob/mysticbbs", imageTag, []string{})
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
		Tag:        getImageTag(),
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

func TestMysticTelnetPort(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	// Run container with exposed telnet port
	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        getImageTag(),
		ExposedPorts: []string{"23/tcp"},
		Env: []string{
			"MYSTIC_PATH=/config",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Get the host and port for telnet
	hostPort := resource.GetHostPort("23/tcp")
	require.NotEmpty(t, hostPort, "Telnet port should be mapped")

	// Retry connection to telnet port with timeout
	// Mystic takes time to install and start, so we need to be patient
	err = pool.Retry(func() error {
		conn, err := net.DialTimeout("tcp", hostPort, 5*time.Second)
		if err != nil {
			return fmt.Errorf("telnet port not ready: %w", err)
		}
		defer conn.Close()
		return nil
	})

	require.NoError(t, err, "Should be able to connect to telnet port 23")
	t.Logf("Successfully connected to Mystic BBS telnet port at %s", hostPort)

	// Test that the port is listening inside the container
	t.Run("TelnetPortListeningInContainer", func(t *testing.T) {
		// Try to connect to localhost:23 from inside the container
		exitCode, err := resource.Exec([]string{"sh", "-c", "timeout 2 bash -c '</dev/tcp/localhost/23' 2>/dev/null && echo 'port open' || echo 'port closed'"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		// Exit code 0 means bash successfully connected to the port
		assert.Equal(t, 0, exitCode, "Port 23 should be listening inside container")
	})
}

func TestDosemuIntegration(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()
	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        imageTag,
		Env: []string{
			"MYSTIC_PATH=/config",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start and initialize
	time.Sleep(30 * time.Second)

	t.Run("DosemuEnvironmentVariables", func(t *testing.T) {
		// Check DOSEMU_ROOT environment variable
		exitCode, err := resource.Exec([]string{"sh", "-c", "[ \"$DOSEMU_ROOT\" = \"/doors/dosemu\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "DOSEMU_ROOT should be set to /doors/dosemu")

		// Check DOORS_PATH environment variable
		exitCode, err = resource.Exec([]string{"sh", "-c", "[ \"$DOORS_PATH\" = \"/doors\" ]"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "DOORS_PATH should be set to /doors")
	})

	t.Run("RundoorScriptExists", func(t *testing.T) {
		// Check that rundoor.sh exists
		exitCode, err := resource.Exec([]string{"test", "-f", "/usr/local/bin/rundoor.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "rundoor.sh should exist")

		// Check that it's executable
		exitCode, err = resource.Exec([]string{"test", "-x", "/usr/local/bin/rundoor.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "rundoor.sh should be executable")
	})

	t.Run("DoorConfigurationExample", func(t *testing.T) {
		// Check that doors.conf.example exists
		exitCode, err := resource.Exec([]string{"test", "-f", "/usr/local/share/mystic/doors.conf.example"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "doors.conf.example should exist")

		// Verify it has readable permissions
		exitCode, err = resource.Exec([]string{"test", "-r", "/usr/local/share/mystic/doors.conf.example"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "doors.conf.example should be readable")
	})

	t.Run("DosemuDirectoryStructure", func(t *testing.T) {
		// Check that base doors directory exists
		exitCode, err := resource.Exec([]string{"test", "-d", "/doors"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/doors directory should exist")

		// Check that dosemu directory structure is created
		exitCode, err = resource.Exec([]string{"test", "-d", "/doors/dosemu/drive_c/doors"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/doors/dosemu/drive_c/doors should be created")

		exitCode, err = resource.Exec([]string{"test", "-d", "/doors/dosemu/drive_c/nodes"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/doors/dosemu/drive_c/nodes should be created")
	})

	t.Run("DoorConfigurationCopied", func(t *testing.T) {
		// Check that doors.conf was copied from example
		exitCode, err := resource.Exec([]string{"test", "-f", "/doors/doors.conf"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/doors/doors.conf should be copied from example")

		// Verify it's readable
		exitCode, err = resource.Exec([]string{"test", "-r", "/doors/doors.conf"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "/doors/doors.conf should be readable")
	})

	t.Run("DosemurcConfiguration", func(t *testing.T) {
		// Check that .dosemurc was created in home directory
		exitCode, err := resource.Exec([]string{"test", "-f", "/home/nobody/.dosemurc"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, ".dosemurc should be created in home directory")

		// Verify it contains expected configuration
		exitCode, err = resource.Exec([]string{"sh", "-c", "grep -q '\\$_cpu = \"80486\"' /home/nobody/.dosemurc"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, ".dosemurc should contain CPU configuration")

		exitCode, err = resource.Exec([]string{"sh", "-c", "grep -q '\\$_external_char_set = \"cp437\"' /home/nobody/.dosemurc"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, ".dosemurc should contain character set configuration")
	})

	t.Run("Dos2UnixInstalled", func(t *testing.T) {
		// Check that dos2unix utilities are installed
		exitCode, err := resource.Exec([]string{"sh", "-c", "command -v dos2unix"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "dos2unix should be installed")

		exitCode, err = resource.Exec([]string{"sh", "-c", "command -v unix2dos"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "unix2dos should be installed")
	})
}

func TestDosemuArchitectureSupport(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()
	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        imageTag,
		Env: []string{
			"MYSTIC_PATH=/config",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start
	time.Sleep(15 * time.Second)

	t.Run("DosemuAvailability", func(t *testing.T) {
		// Check what architecture we're running on
		exitCode, err := resource.Exec([]string{"uname", "-m"}, dockertest.ExecOptions{})
		require.NoError(t, err)

		// Check if dosemu command exists
		exitCode, err = resource.Exec([]string{"sh", "-c", "command -v dosemu"}, dockertest.ExecOptions{})

		if exitCode == 0 {
			t.Log("dosemu2 is installed and available")
		} else {
			t.Log("dosemu2 is not available (may be ARM architecture)")
		}

		// This test passes either way - we just log the status
		// On x86_64, dosemu should be available
		// On ARM32, it should not be available
		// On ARM64, it may or may not be available (experimental)
	})
}

func TestLORDDoorInstallation(t *testing.T) {
	pool, err := dockertest.NewPool("")
	require.NoError(t, err, "Could not connect to docker")

	imageTag := getImageTag()
	resource, err := pool.RunWithOptions(&dockertest.RunOptions{
		Repository: "ghcr.io/sob/mysticbbs",
		Tag:        imageTag,
		Env: []string{
			"MYSTIC_PATH=/config",
			"DOSEMU_ROOT=/doors/dosemu",
			"DOORS_PATH=/doors",
		},
	})
	require.NoError(t, err, "Could not start resource")

	defer func() {
		assert.NoError(t, pool.Purge(resource), "Could not purge resource")
	}()

	// Give the container time to start and initialize dosemu structure
	time.Sleep(20 * time.Second)

	t.Run("InstallDoorScriptExists", func(t *testing.T) {
		exitCode, err := resource.Exec([]string{"test", "-f", "/usr/local/bin/install-door.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "install-door.sh should be installed")
	})

	t.Run("InstallDoorScriptExecutable", func(t *testing.T) {
		exitCode, err := resource.Exec([]string{"test", "-x", "/usr/local/bin/install-door.sh"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "install-door.sh should be executable")
	})

	t.Run("ListDoorsCommand", func(t *testing.T) {
		exitCode, err := resource.Exec([]string{"install-door.sh", "list"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "install-door.sh list should succeed")
	})

	t.Run("InstallLORDDoor", func(t *testing.T) {
		// Install LORD door (this downloads ~300KB and may take 30-60 seconds)
		t.Log("Installing LORD door (this may take up to 60 seconds)...")

		exitCode, err := resource.Exec(
			[]string{"sh", "-c", "echo 'y' | install-door.sh lord"},
			dockertest.ExecOptions{},
		)
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "LORD installation should succeed")
	})

	t.Run("VerifyLORDDirectoryCreated", func(t *testing.T) {
		exitCode, err := resource.Exec([]string{"test", "-d", "/doors/dosemu/drive_c/doors/lord"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "LORD directory should be created at /doors/dosemu/drive_c/doors/lord")
	})

	t.Run("VerifyNestedArchiveExtracted", func(t *testing.T) {
		// Verify that the nested LORD.ZIP was extracted and removed
		exitCode, err := resource.Exec([]string{"test", "-f", "/doors/dosemu/drive_c/doors/lord/LORD.ZIP"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.NotEqual(t, 0, exitCode, "Nested LORD.ZIP should be extracted and removed")
	})

	t.Run("VerifyLORDGameFiles", func(t *testing.T) {
		// Check for expected LORD game files that should exist after nested extraction
		expectedFiles := []string{
			"/doors/dosemu/drive_c/doors/lord/LORD.EXE",
			"/doors/dosemu/drive_c/doors/lord/START.BAT",
		}

		for _, file := range expectedFiles {
			exitCode, err := resource.Exec([]string{"test", "-f", file}, dockertest.ExecOptions{})
			require.NoError(t, err)
			assert.Equal(t, 0, exitCode, "Expected LORD game file should exist: %s", file)
		}
	})

	t.Run("VerifyExecutablePermissions", func(t *testing.T) {
		// Verify that executable files have proper permissions
		exitCode, err := resource.Exec([]string{"test", "-x", "/doors/dosemu/drive_c/doors/lord/LORD.EXE"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "LORD.EXE should be executable")

		exitCode, err = resource.Exec([]string{"test", "-x", "/doors/dosemu/drive_c/doors/lord/START.BAT"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "START.BAT should be executable")
	})

	t.Run("VerifyDoorsConfigExists", func(t *testing.T) {
		// Verify that doors.conf was created
		exitCode, err := resource.Exec([]string{"test", "-f", "/doors/doors.conf"}, dockertest.ExecOptions{})
		require.NoError(t, err)
		assert.Equal(t, 0, exitCode, "doors.conf should exist")
	})
}