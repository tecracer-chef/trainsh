# TrainSH

## Summary

Interactive Shell for Remote Systems

Based on the Train ecosystem, provide a shell to manage systems via a multitude of transports.

Train default supports:

- Docker
- Local
- SSH (Unix, Windows, Cisco)
- WinRM (Windows)

3rd party plugins support:

- AWS Systems Manager
- LXD
- Telnet
- Serial/USB interfaces
- VMware Guest Operations (VMware Tools)
- ...

## Example uses

When specifying a password within an URL take care of special characters or the connection will fail.

```shell
trainsh connect local://
```

```shell
trainsh connect winrm://Administrator:Passw0rd@10.20.30.40
```

```shell
trainsh connect awsssm://i-123456789abc0
```

```shell
trainsh connect vsphere-gom://example-vm
```

If the transport has additional options like `key_files`, they need to be added as URL parameters (`ssh://10.20.30.40/?key_files=~/.ssh/id_rsa2`).

## Shell commands

There are three separate categories of commands when in the Shell:

- remote commands
- local commands, which are prefixed with `.`
- built-in commands, wich are prefixed with `!`

Anything you type without a prefix gets executed 1:1 on the remote system. Please notice that Train is headless, so any interactive programs will not work but lock up your shell! If you need to edit remote files or use a pager (like `less`), please look into the Built-In Commands section.

Local commands get executed 1:1 on your local system, so you are able to check things locally or change paths, for example.

There is also the Sessionprefix `@`, which is described briefly in the "Prompt and Sessions" section.

## Built-In Commands

`!!!`
Quit TrainSH. Aliases: `quit`, `exit`, `logout`, `disconnect`.

`!clear-history`
Clear your TrainSH history, for example to remove clutter or sensitive information

`!connect <uri>`
Connect to another system. The URI needs to match the format of the used Train transport, which is usually `transportname://host` but varies. See the Train transport's documentation for details.

`!copy @<session>:/<path> @<session>:/<path>`
Copy a file between two established sessions.

`!detect`
Re-runs the OS detection which is running automatically on start. This will determine the OS, OS-family and general platform information via Train.

`!download <remote> <local>`
Download a file to the local system. You need to specify the target, if you want to keep the name just use `.` as local part.

`!edit <remotefile>`
Downloads the remote file as temporary file and opens the system default editor locally (`EDITOR` and `VISUAL` environment variables, with fallback to `vi`). Upon exiting the file, it will be uploaded again and overwrite the remote file.

`!env`
Prints the environment variables of your remote shell. This will be filled on first command invocation to save IO. **Currently unsupported for Windows remote systems**

`!help`
Print out help

`!history`
Output your TrainSH command history. As this uses the popular Readline library, you can also navigate your history with the Up/Down arrows or use Ctrl-R for reverse search. You can do auto completion for built-in commands.

`!host`
Outputs the remote hostname.

`!ping`
Executes a simple command to measure roundtrip/overhead time.

`!pwd`
Output the remote working directory. This will be filled on first command invocation to save IO.

`!read <remotefile>`
Download the specified file and display it in the system default pager (`PAGER` environment variable, with fallback to `less`).

`!reconnect`
Quits and reopens the current session.

`!sessions`
List all currently active sessions (See "Prompt and Sessions" section). Password information is redacted for security reasons.

`!session <session_id>`
Change to another session by passing its ID (=number)

`!upload <local> <remote>`
Upload files to the target machine

## Prompt and Sessions

`OK trainsh(@0 local://trc4023)>`

The prompt consists roughly of three areas:

- Exit code of last command ("OK" or the exit code in format `Exx` with xx being the numeric code)
- Session indication
- Input area

The session indication includes the ID of the session, so `@0` means session 0, `@1` means session 1 and so on. The second part shows the Train URI for the remote system for easy identification.

Any TrainSH invocation has at minimum one active session but if you want, you can add more sessions with the `!connect <uri>` built-in. Every session has its own Train backend and storage of current working directory, environment variables etc. You can list active sessions with `!sessions` and switch between them using `!session <session_id>`.

If you want to execute commands on another session ad-hoc, you can prefix it with the session id: `@1 uname -a` will execute the `uname -a` command on session ID 1.

Depending on the transport and target, the time between sending a command and retrieving the result will vary widely. In TrainSH this is called the "ping", which measures the minimum overhead/latency for the session. It varies massively between Train plugins and is not only related to the network distance, but also to the way of command execution - which might involve a number of HTTPS requests or the time to invoke a remote shell (examples: AWS SSM and VSphere GOM transports).

### Under the Hood

As Train is headless/stateless system, there will be various pre- and postfixed commands to make your life easier. This means that any state-related commands like changing the current directory or modification of environment variables would be unavailable for the next command - as it technically is a separate shell.

To make this easier, internal commands get attached to your input like this:

- Prefix: Get remote hostname (discovery task, just on first execution)
- Prefix: Set previous environment variables
- Prefix: Set previous path
- Command
- Postfix: Retrieve and save exit code of command
- Postfix: Retrieve and save new path
- Postfix: Retrieve and save new environment variables

Output of commands gets separated by outputting a highly random string between, which should not result in false positives. If a false positive occurs for some reason, TrainSH will fail and output an error.

## Target Detection

As providing target URLs to connect to can be tedious, TrainSH will detect targets to connect to via plugins. In these cases, `trainsh connect` does not need any parameters.

### Environment Variables

This will check the `TARGET` environment variable for a URL and use it to connect. Only one target is allowed.

### Test Kitchen Configuration

This will detect if the current directory has a Test Kitchen configuration and a created machine. If so, it will connect to the machine by parsing information in `.kitchen/` and the kitchen configuration file.
