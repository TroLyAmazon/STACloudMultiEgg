package main

import (
	"bufio"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/binary"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/creack/pty"
	"golang.org/x/crypto/ssh"
)

const (
	homeDir         = "/home/container"
	credentialsFile = homeDir + "/.stacloud_credentials"
	hostKeyFile     = homeDir + "/.stacloud_ssh_host_key"
	prootBinary     = "/usr/local/bin/proot"
)

var (
	alphaLower = []byte("abcdefghijklmnopqrstuvwxyz0123456789")
	alphaMixed = []byte("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
)

type credentials struct {
	User     string
	Password string
	Port     string
}

type ptyState struct {
	term string
	rows uint32
	cols uint32
}

func main() {
	log.SetFlags(0)

	creds, err := loadOrCreateCredentials()
	if err != nil {
		log.Fatalf("[ERROR] %v", err)
	}

	signer, err := loadOrCreateHostSigner()
	if err != nil {
		log.Fatalf("[ERROR] %v", err)
	}

	config := &ssh.ServerConfig{
		ServerVersion: "SSH-2.0-STACloud",
		PasswordCallback: func(conn ssh.ConnMetadata, password []byte) (*ssh.Permissions, error) {
			if conn.User() == creds.User && string(password) == creds.Password {
				return nil, nil
			}
			return nil, errors.New("invalid SSH credentials")
		},
	}
	config.AddHostKey(signer)

	listener, err := net.Listen("tcp", "0.0.0.0:"+creds.Port)
	if err != nil {
		log.Fatalf("[ERROR] SSH listen failed on port %s: %v", creds.Port, err)
	}
	defer listener.Close()

	log.Printf("[SUCCESS] STACloud SSH listening on port %s", creds.Port)

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("[ERROR] SSH accept failed: %v", err)
			continue
		}
		go handleConnection(conn, config)
	}
}

func loadOrCreateCredentials() (credentials, error) {
	creds := credentials{}

	values, _ := readKeyValues(credentialsFile)
	creds.User = values["SSH_LOGIN"]
	creds.Password = values["SSH_SECRET"]
	creds.Port = resolvePort(os.Getenv("SSH_PORT"), os.Getenv("SERVER_PORT"))

	if !validUsername(creds.User) {
		user, err := randomString(10, alphaLower)
		if err != nil {
			return creds, err
		}
		creds.User = "sta" + user
	}

	if !validPassword(creds.Password) {
		password, err := randomString(24, alphaMixed)
		if err != nil {
			return creds, err
		}
		creds.Password = password
	}

	if err := os.MkdirAll(homeDir, 0755); err != nil {
		return creds, err
	}

	data := fmt.Sprintf("SSH_LOGIN=%s\nSSH_SECRET=%s\n", creds.User, creds.Password)
	if err := os.WriteFile(credentialsFile, []byte(data), 0600); err != nil {
		return creds, err
	}

	return creds, nil
}

func readKeyValues(path string) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	values := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		values[strings.TrimSpace(parts[0])] = strings.Trim(strings.TrimSpace(parts[1]), `"'`)
	}
	return values, scanner.Err()
}

func validUsername(user string) bool {
	if len(user) < 6 || len(user) > 32 || !strings.HasPrefix(user, "sta") {
		return false
	}
	for _, ch := range user {
		if (ch < 'a' || ch > 'z') && (ch < '0' || ch > '9') {
			return false
		}
	}
	return true
}

func validPassword(password string) bool {
	return len(password) >= 12 && len(password) <= 128
}

func resolvePort(sshPort, serverPort string) string {
	port := strings.TrimSpace(sshPort)
	switch port {
	case "", "{{SERVER_PORT}}", "{{server.build.default.port}}":
		port = strings.TrimSpace(serverPort)
	}
	if _, err := strconv.Atoi(port); err != nil || port == "" {
		return "2222"
	}
	return port
}

func randomString(length int, alphabet []byte) (string, error) {
	output := make([]byte, length)
	randomBytes := make([]byte, length)
	if _, err := rand.Read(randomBytes); err != nil {
		return "", err
	}
	for i, value := range randomBytes {
		output[i] = alphabet[int(value)%len(alphabet)]
	}
	return string(output), nil
}

func loadOrCreateHostSigner() (ssh.Signer, error) {
	if data, err := os.ReadFile(hostKeyFile); err == nil {
		return ssh.ParsePrivateKey(data)
	}

	key, err := rsa.GenerateKey(rand.Reader, 3072)
	if err != nil {
		return nil, err
	}

	keyBytes := x509.MarshalPKCS1PrivateKey(key)
	block := &pem.Block{Type: "RSA PRIVATE KEY", Bytes: keyBytes}
	data := pem.EncodeToMemory(block)
	if data == nil {
		return nil, errors.New("failed to encode SSH host key")
	}

	if err := os.MkdirAll(filepath.Dir(hostKeyFile), 0755); err != nil {
		return nil, err
	}
	if err := os.WriteFile(hostKeyFile, data, 0600); err != nil {
		return nil, err
	}

	return ssh.ParsePrivateKey(data)
}

func handleConnection(raw net.Conn, config *ssh.ServerConfig) {
	defer raw.Close()

	conn, channels, requests, err := ssh.NewServerConn(raw, config)
	if err != nil {
		return
	}
	defer conn.Close()

	go ssh.DiscardRequests(requests)

	for newChannel := range channels {
		if newChannel.ChannelType() != "session" {
			newChannel.Reject(ssh.UnknownChannelType, "session channels only")
			continue
		}

		channel, requests, err := newChannel.Accept()
		if err != nil {
			continue
		}
		go handleSession(channel, requests)
	}
}

func handleSession(channel ssh.Channel, requests <-chan *ssh.Request) {
	defer channel.Close()

	state := ptyState{term: "xterm-256color", rows: 24, cols: 80}
	var started bool
	var processDone <-chan int
	var resizeMu sync.Mutex
	var tty *os.File

	for req := range requests {
		switch req.Type {
		case "pty-req":
			updatePtyState(req.Payload, &state)
			req.Reply(true, nil)
		case "window-change":
			updateWindowState(req.Payload, &state)
			resizeMu.Lock()
			if tty != nil {
				_ = pty.Setsize(tty, &pty.Winsize{Rows: uint16(state.rows), Cols: uint16(state.cols)})
			}
			resizeMu.Unlock()
		case "shell":
			if started {
				req.Reply(false, nil)
				continue
			}
			started = true
			req.Reply(true, nil)
			var done <-chan int
			tty, done = startCommand(channel, "", state)
			processDone = done
		case "exec":
			if started {
				req.Reply(false, nil)
				continue
			}
			command := parseExecCommand(req.Payload)
			started = true
			req.Reply(true, nil)
			var done <-chan int
			tty, done = startCommand(channel, command, state)
			processDone = done
		case "env":
			req.Reply(true, nil)
		default:
			req.Reply(false, nil)
		}

		if started {
			break
		}
	}

	if !started {
		return
	}

	go drainSessionRequests(requests, &state, &resizeMu, &tty)

	status := <-processDone
	_, _ = channel.SendRequest("exit-status", false, ssh.Marshal(struct{ Status uint32 }{uint32(status)}))
	time.Sleep(100 * time.Millisecond)
}

func drainSessionRequests(requests <-chan *ssh.Request, state *ptyState, resizeMu *sync.Mutex, tty **os.File) {
	for req := range requests {
		switch req.Type {
		case "window-change":
			updateWindowState(req.Payload, state)
			resizeMu.Lock()
			if *tty != nil {
				_ = pty.Setsize(*tty, &pty.Winsize{Rows: uint16(state.rows), Cols: uint16(state.cols)})
			}
			resizeMu.Unlock()
		default:
			req.Reply(false, nil)
		}
	}
}

func updatePtyState(payload []byte, state *ptyState) {
	term, rest, ok := parseSSHString(payload)
	if !ok || len(rest) < 16 {
		return
	}
	state.term = term
	state.cols = binary.BigEndian.Uint32(rest[0:4])
	state.rows = binary.BigEndian.Uint32(rest[4:8])
	if state.cols == 0 {
		state.cols = 80
	}
	if state.rows == 0 {
		state.rows = 24
	}
}

func updateWindowState(payload []byte, state *ptyState) {
	if len(payload) < 16 {
		return
	}
	state.cols = binary.BigEndian.Uint32(payload[0:4])
	state.rows = binary.BigEndian.Uint32(payload[4:8])
	if state.cols == 0 {
		state.cols = 80
	}
	if state.rows == 0 {
		state.rows = 24
	}
}

func parseExecCommand(payload []byte) string {
	command, _, ok := parseSSHString(payload)
	if !ok {
		return ""
	}
	return command
}

func parseSSHString(payload []byte) (string, []byte, bool) {
	if len(payload) < 4 {
		return "", nil, false
	}
	length := int(binary.BigEndian.Uint32(payload[0:4]))
	if length < 0 || len(payload) < 4+length {
		return "", nil, false
	}
	return string(payload[4 : 4+length]), payload[4+length:], true
}

func startCommand(channel ssh.Channel, command string, state ptyState) (*os.File, <-chan int) {
	done := make(chan int, 1)

	cmd := exec.Command(prootBinary, prootArgs(command)...)
	cmd.Env = append(os.Environ(),
		"HOME=/home/container",
		"USER=root",
		"LOGNAME=root",
		"TERM="+state.term,
	)

	tty, err := pty.StartWithSize(cmd, &pty.Winsize{Rows: uint16(state.rows), Cols: uint16(state.cols)})
	if err != nil {
		_, _ = fmt.Fprintf(channel.Stderr(), "[ERROR] Failed to start shell: %v\r\n", err)
		done <- 1
		close(done)
		return nil, done
	}

	go func() {
		_, _ = io.Copy(tty, channel)
		_ = tty.Close()
	}()

	go func() {
		_, _ = io.Copy(channel, tty)
	}()

	go func() {
		err := cmd.Wait()
		exitCode := 0
		if err != nil {
			var exitErr *exec.ExitError
			if errors.As(err, &exitErr) {
				if status, ok := exitErr.Sys().(syscall.WaitStatus); ok {
					exitCode = status.ExitStatus()
				} else {
					exitCode = 1
				}
			} else {
				exitCode = 1
			}
		}
		done <- exitCode
		close(done)
		_ = tty.Close()
	}()

	return tty, done
}

func prootArgs(command string) []string {
	shellCommand := command
	if strings.TrimSpace(shellCommand) == "" {
		shellCommand = "cd /home/container 2>/dev/null || cd /; if command -v bash >/dev/null 2>&1; then exec bash -l; else exec sh -l; fi"
	}

	return []string{
		"-r", homeDir,
		"-0",
		"-w", "/home/container",
		"-b", "/dev",
		"-b", "/proc",
		"-b", "/sys",
		"/bin/sh",
		"-lc",
		shellCommand,
	}
}
