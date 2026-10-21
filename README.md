# To-Do List Tracker in x86-64 NASM Assembly

A command-line task manager written in **x86-64 NASM assembly** for Linux. It talks to the kernel
directly through system calls (file I/O and console I/O), parses user commands by hand, and keeps its
data in a plain text file.

Course project for **Assembly Language**, University of Tehran. The assignment was designed by
Artin Abbaspour. The program skeleton (`main.asm`, `lib/`, `build.sh`) was provided by the course; the
command handlers in `commands/` are my implementation.

## Commands

| Command | What it does |
|---|---|
| `ADD "text"` | Add a pending task (low priority by default) |
| `ADD ! "text"`, `ADD * "text"`, `ADD . "text"` | Add a task with high (`!`), medium (`*`) or low (`.`) priority |
| `LIST` | Show all tasks, `[ ]` for pending and `[X]` for done |
| `DONE <id>` | Mark a task as completed |
| `EDIT <id> "new text"` | Replace a task's description |
| `DELETE <id>` | Remove a task (IDs are never renumbered) |
| `CLEAR` | Remove all tasks |
| `ARCHIVE` | Move completed tasks to `data/archive.txt` |
| `STATS` *(bonus)* | Total, completed, pending and completion percentage |
| `SORT STATUS` *(bonus)* | Pending tasks first, then completed |
| `SORT PRIORITY` *(bonus)* | High, then medium, then low priority |
| `EXIT` | Quit the program |

Commands are case-sensitive (uppercase). Descriptions must be in double quotes; the quotes are not stored.

## Data format

Tasks live in `data/todo.txt`, one per line:

```
ID|STATUS|PRIORITY|DESCRIPTION
```

```
1|P|.|Wash car
2|D|!|Fix bugs
3|P|*|Buy groceries
```

`STATUS` is `P` (pending) or `D` (done). `PRIORITY` is `!` (high), `*` (medium) or `.` (low).

## Highlights of the implementation

- **Read, rebuild, rewrite:** commands that change the file (`DONE`, `EDIT`, `DELETE`, `ARCHIVE`, `SORT`) read
  `todo.txt` into a buffer, walk it line by line into a second buffer, then recreate the file and write the new
  contents back.
- **Safe on bad data:** malformed lines are skipped by `LIST` and kept untouched by the commands that rewrite the file.
  `DONE` only changes the status character if it really is `P`.
- **No renumbering:** a new ID is the largest existing ID plus one.
- **Hand-written conversions:** numbers are turned into text by repeated division by 10 (and the percentage in
  `STATS` is `completed * 100 / total` with a zero-division check).
- **Direct system calls where useful:** `LIST` prints ID and description with `sys_write` and exact lengths, because
  those parts of the buffer are not null-terminated.
- **`rep movsb`** is used to copy lines in `ARCHIVE` and `SORT`.
- **`SORT`** is a multi-pass copy (for example `!`, then `*`, then `.`) with a final pass that appends malformed lines.

The full per-command write-up (algorithms, helper routines, and the `.data` / `.bss` variables) is in
[`docs/Project_Report_EN.md`](docs/Project_Report_EN.md).

## Repository structure

```
commands/    add_task, list_tasks, mark_done, edit_task, delete_task, clear_tasks,
             archive_tasks, stats, sort_tasks (.asm)
docs/        English implementation report
```

## Build and run

The skeleton files (`main.asm`, `lib/string_utils.asm`, `lib/file_ops.asm`, `build.sh`) come from the course and are
**not included** in this repository. To build, place them next to the `commands/` folder of this repository, then on
Linux (or WSL) with NASM installed:

```bash
chmod +x build.sh
./build.sh
```

The program starts with the prompt `ToDo>` and runs until you type `EXIT`.

## Limitations

- The task file is read into fixed-size buffers (4096 bytes for most commands), so very large task files are not supported.
- A description is limited to 256 bytes.
- Commands are case-sensitive and expected in uppercase.
- No automated test suite is included.

## License

MIT
