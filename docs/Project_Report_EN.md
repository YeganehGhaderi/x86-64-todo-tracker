# Implementation Report: To-Do List Tracker (x86-64 NASM Assembly)

**Author:** Yeganeh Ghaderi
**Course:** Assembly Language, University of Tehran

*English translation of the original Persian report. Each section describes one command handler: its overall
algorithm, its helper routines, and the variables added in `.data` and `.bss`.*

## Overview of the common design

*(Added for the English version; it summarises what the sections below describe.)*

- Commands that change the file (`DONE`, `EDIT`, `DELETE`, `ARCHIVE`, `SORT`) read `todo.txt` into a buffer, go through
  it line by line, build the new contents in a second buffer, and then recreate the file with `createFile` and write
  the new contents.
- Lines that do not have the expected structure are skipped (`LIST`) or preserved (the rewriting commands),
  so malformed data never crashes the program or gets destroyed.
- The provided helper functions (`appendFile`, `createFile`, `writeFile`, `closeFile`, `strcmp`, `printString`) are used for
  file and console operations.

---

## 1. ADD command (`add_task.asm`)

**Overall algorithm**

1. **Input parsing:** first it skips the word `ADD` and the spaces, then looks for a priority character, `!` or `*`
   (or `.`). If none is present, the default priority `.` is used. After that, the input must start with `"`;
   otherwise a syntax error is printed. Then the characters up to the second `"` are copied into `add_desc_buf`.
2. **ID generation:** the whole file `todo.txt` is read into `add_buffer`, and the largest existing ID (Max ID) is
   extracted. The new ID is `Max ID + 1`.
3. **Type conversion:** the new ID, which is an integer, is converted into an ASCII text string.
4. Finally, the record `ID|P|PRIORITY|DESCRIPTION\n` is built in `add_record_buf` and appended to the end of
   `todo.txt` using the provided `appendFile` function.

**Logical routines**

- `.add_id_loop`: a loop that scans `add_buffer` and extracts the numbers before the first `|` of each line in order
  to find the Max ID.
- `.add_int_to_str`: a loop that converts a number to a string by repeated division by 10 and storing the remainders.
- `.add_malformed_skip`: if a non-numeric character is met in the ID part, it moves the pointer forward to the end
  of that line (`\n`) so the program does not crash.

**Variables in `.data`**

- `add_success_msg`: the success message.
- `add_syntax_err`: the syntax-error message, printed when the quote format is not respected or the description is empty.

**Variables in `.bss`**

- `add_priority` (1 byte): stores the extracted priority character.
- `add_desc_buf` (256 bytes): temporary buffer for the description extracted between the quotes.
- `add_buffer` (4096 bytes): main buffer for reading the whole `todo.txt` to find the Max ID.
- `add_id_str` (16 bytes): buffer holding the text form of the new ID.
- `add_record_buf` (512 bytes): final buffer for building the string `ID|P|PRIO|DESC\n` before writing it to the file.

---

## 2. LIST command (`list_tasks.asm`)

**Overall algorithm**

`handle_list` starts by reading the whole file `todo.txt` into `list_buffer`. If the file is empty or missing, it
prints `Empty list.` Otherwise it enters a loop that walks the file contents line by line. In each line it looks for
3 `|` characters and saves the index of each one when it reaches it. Using these indexes it reads the **Status** field
(between the first and second `|`) and prints `[ ]` or `[X]` accordingly. Then it extracts the **ID** and finally the
**Description** and prints them.

**Note:** if a line is incomplete and its number of `|` characters does not reach 3, the program ignores it without
crashing, by jumping to `skip_line`, and moves on to the next line. The register `r15` is also used as a flag so that
the title `--- To-Do List ---` is printed only if at least one valid task exists in the file.

**Logical routines**

- `.find_pipes` and `.save_pipe1` / `.save_pipe2` / `.save_pipe3`: a scanning loop that checks the characters of each
  line and, as soon as it finds a `|`, saves its index in the registers `r8`, `r9` and `r10` in order.
- `.print_id`: instead of the helper `printString`, this routine uses the Linux system call `sys_write` directly to
  print the ID and the description. These values are part of a larger string (`list_buffer`) and have no null
  terminator at their end, so the routine computes their exact length by subtracting indices and prints them with a
  direct `sys_write`. This is faster and avoids the risk of interfering with memory writes.

**Variables in `.data`**

- `list_header`: the title string above the task list.
- `list_empty_msg`: the message printed when `todo.txt` is empty.
- `done_str` and `pending_str`: the markers `[X] ` and `[ ] ` printed before done and pending tasks respectively.
- `colon_space`: the string `": "` printed between the ID and the description.

**Variables in `.bss`**

- `list_buffer` (4096 bytes): main buffer holding the whole content read from `todo.txt`, used to extract information in memory.

---

## 3. DONE command (`mark_done.asm`)

**Overall algorithm**

`handle_done` starts by extracting the ID from `input_buffer`. It then reads the whole `todo.txt` into `done_read_buf`
and, with a loop, reads this buffer line by line. In each line, the characters before the first `|` are taken as the ID
of that line and compared with the ID entered by the user (using the provided `strcmp` function).

If the IDs match, the line is copied character by character into `done_write_buf` by `.done_copy_char`. During the copy,
if it reaches the status character (the one immediately after the first `|`) and that character is `P`, it changes it to
`D`. If the IDs do not match, the original line is copied completely and unchanged. Finally, the original file is erased
using the provided `createFile` function and the content of `done_write_buf` is written to it.

**Note:** in `.done_copy_char`, a check `cmp al, 'P'` is placed before replacing the character with `D`. This guarantees
that if a line does not have the standard structure, or if the task already has the status `D`, the program does not
wrongly modify other characters and the file contents are not corrupted.

**Logical routines**

- `.done_extract_id`: a loop that extracts the ID of the current line, up to the first `|` or the end of the line (0),
  and stores it in `done_id_str_buf`.
- `.done_copy_char`: this routine changes the status of the target line. Using a counter (`rbx`) it counts the `|`
  characters passed, and exactly when the first `|` is passed, if the ID of the current line equals the target ID, it
  replaces `P` with `D`.

**Variables in `.data`**

- `done_success_msg`: the success message.
- `done_syntax_err`: the syntax-error message if the user does not enter an ID.
- `done_not_found`: contains `Task ID not found.`, printed if the entered ID does not match any ID in `todo.txt`.

**Variables in `.bss`**

- `done_id_str_buf` (16 bytes): stores the ID string entered by the user.
- `done_read_buf` (4096 bytes): holds the original content of `todo.txt` before changes.
- `done_write_buf` (4096 bytes): holds the new file content after the status of the requested ID has been changed.
- `done_line_id_buf` (16 bytes): temporary buffer for extracting the ID of each line during the loop, for comparison.

---

## 4. EDIT command (`edit_task.asm`)

**Overall algorithm**

`handle_edit` starts by walking through the user input, `input_buffer`. It first extracts the ID, and then stores the
new description, which is inside double quotes, in `edit_new_desc_buf`. After reading the file `todo.txt` into
`edit_read_buf`, a loop runs through this buffer line by line. In each line it compares the extracted ID with the
target ID.

If they match, instead of copying the whole line, the program copies only a prefix of the line (exactly up to and
including the third `|`, that is, up to before the old description), then appends the new description to it and skips
the rest of the old line until the `\n` character (with `.edit_skip_old_rest`). If they do not match, the whole line is
copied unchanged (via `.edit_copy_full_line`). Finally, the new contents in `edit_write_buf` are written back to
`todo.txt`.

**Logical routines**

- `.edit_copy_prefix`: a loop that copies the characters of a line and, by counting `|` characters, stops exactly after
  passing the third `|` (the end of the priority field), so the old description is not copied.
- `.edit_append_new_desc`: appends the new description extracted from the user input to the end of the copied prefix in
  the output buffer (`edit_write_buf`).
- `.edit_skip_old_rest`: after the new description has been added, this routine advances the read pointer in the
  original file up to the next line, so that the old description, which is no longer needed, is not placed in
  `edit_write_buf`.
- `.edit_copy_full_line`: used for lines whose ID does not match the target ID. It moves the whole line unchanged into
  `edit_write_buf`.

**Variables in `.data`**

- `edit_success_msg`: the success message.
- `edit_syntax_err`: the syntax-error message if the quotes are forgotten or the new description is empty.
- `edit_not_found`: contains `Task ID not found.`, printed if the requested ID does not exist in `todo.txt`.

**Variables in `.bss`**

- `edit_id_str_buf` (16 bytes): stores the ID string entered by the user.
- `edit_new_desc_buf` (256 bytes): holds the new description after the quotes are removed.
- `edit_write_buf` and `edit_read_buf` (4096 bytes each): hold the original content of `todo.txt` and build its new version.
- `edit_line_id_buf` (16 bytes): temporary buffer for extracting the ID of each line during the loop.

---

## 5. DELETE command (`delete_task.asm`)

**Overall algorithm**

`handle_delete` starts by skipping the word `DELETE` and extracting the target ID from the user input. It then reads the
whole `todo.txt` into `delete_read_buf` and runs a loop through this buffer line by line. In each line it extracts the ID
and compares it with the target ID. If the IDs do not match, the whole line, together with its `\n` character, is copied
into `delete_write_buf`. If they match, a flag is set and the program jumps to a routine that skips copying that line and
goes straight to the next line. Finally, the original file is erased and the new contents in `delete_write_buf` are
written to it.

**Note:** if the user deletes the only existing task, nothing is written to the output buffer, and `createFile` opens the
file and `writeFile` is called with length zero. The result is a completely empty `todo.txt`.

**Logical routines**

- `.delete_extract_id`: a loop that reads the characters of a line from the start up to the first `|` or the end of the
  line, to extract the ID for comparison.
- `.delete_copy_char` and `.delete_keep_line`: when the IDs do not match, these copy the current line character by
  character into `delete_write_buf`.
- `.delete_find_nl` and `.delete_skip_to_next_line`: when the IDs match, these advance the pointer from the current
  character of the line to the `\n` character, in order to jump to the next line without writing anything to the final buffer.

**Variables in `.data`**

- `delete_success_msg`: the success message.
- `delete_syntax_err`: the syntax-error message if the user does not enter an ID.
- `delete_not_found`: contains `Task ID not found.`, printed if the target ID is not found in `todo.txt`.

**Variables in `.bss`**

- `delete_id_str_buf` (16 bytes): stores the ID string entered by the user.
- `delete_read_buf` (4096 bytes): buffer for reading the original content of `todo.txt`.
- `delete_write_buf` (4096 bytes): buffer for building the new version of the file, without the deleted line.
- `delete_line_id_buf` (16 bytes): temporary buffer holding the ID of the current line during the loop.

---

## 6. CLEAR command (`clear_tasks.asm`)

**Overall algorithm**

`handle_clear` does not need to read the contents of `todo.txt` or parse the user input (the `CLEAR` command has no
arguments). It directly opens `todo.txt` with the `createFile` function, which truncates it. After checking that this
operation succeeded, it immediately closes the file using the file descriptor and prints the success message.

**Variables in `.data`**

- `clear_success_msg`: the success message shown to the user after the file has been closed.

---

## 7. ARCHIVE command (`archive_tasks.asm`)

**Overall algorithm**

`handle_archive` starts by reading the whole `todo.txt` into `archive_read_buf`. It then opens the file
`data/archive.txt` with the provided `appendFile` function so that the write pointer points to the end of this file.
After that it runs a loop through the content of `archive_read_buf` line by line. In each line it extracts the status
character (between the first and second `|`).

If this character is `D`, the line is written directly to `archive.txt` and is not written to `archive_write_buf`
(writing directly avoids taking unnecessary space in RAM buffers). If the status is `P`, or the line is incomplete, the
line is added to `archive_write_buf`. After the loop, `archive.txt` is closed and, if at least one `D` task was found
(checked with the flag `r14`), `todo.txt` is rewritten.

**Note:** when writing to `archive.txt`, the routine checks whether the line ends with the character `\n` or with a null
character. This prevents the last archived line from being glued to earlier lines in this file.

**Logical routines**

- `.archive_find_status`: a loop that finds the first `|` and extracts the status character right after it.
- `.archive_calc_len`: calculates the exact length of each line (up to before `\n`), to know how many bytes must be
  written to `archive.txt` or copied into `archive_write_buf`.
- `.archive_keep_line`: used for pending lines. Instead of a slow character-by-character copy loop, it uses the
  `rep movsb` instruction to copy the data faster.

**Variables in `.data`**

- `archive_filename`: the path string of the archive file (`data/archive.txt`).
- `archive_success_msg`: the success message.
- `archive_empty_msg`: contains `No completed tasks to archive.`, printed if there is no done task in the file.

**Variables in `.bss`**

- `archive_read_buf` (4096 bytes): buffer for reading the initial content of `todo.txt`.
- `archive_write_buf` (4096 bytes): buffer for building the new version of `todo.txt`, which contains only pending
  tasks and incomplete lines.

---

## 8. STATS command (`stats.asm`) *(bonus)*

**Overall algorithm**

`handle_stats` starts by zeroing the counter registers (total, done, pending and percentage). It then reads `todo.txt`.
If the file is empty, the program skips the calculation part completely and goes straight to printing the zero values.
Otherwise it runs a loop line by line that ignores empty lines and, for each non-empty line, first increments the total
counter (`r8`). Then, by counting `|` characters, it extracts the status character. If it is `D`, the done counter
(`r9`) is incremented, and if it is `P`, the pending counter (`r10`) is incremented. After the loop, the completion
percentage is computed as `(r9 * 100) / r8` and all statistics are printed in the required format.

**Logical routines**

- `.stats_print_int`: a helper routine that converts the integer in `rax` to an ASCII string and prints it. It divides
  the number by 10, converts the remainder to a character, and fills a buffer from its end towards the front so that the
  digits come out in the right order.

**Variables in `.data`**

- `stats_header`: the title above the table, `--- Task Statistics ---`.
- `stats_total_str`, `stats_done_str`, `stats_pend_str`, `stats_perc_str`: text labels for each extracted statistic.
- `stats_newline` and `stats_percent_s`: the percent sign and the newline character, for a neat output.

**Variables in `.bss`**

- `stats_read_buf` (4096 bytes): buffer for reading `todo.txt` to go through it and extract the statistics.
- `stats_num_buf` (16 bytes): temporary buffer used in `.stats_print_int` to build the number string before printing.

---

## 9. SORT command (`sort_tasks.asm`) *(bonus)*

**Overall algorithm**

1. First it skips the word `SORT` (4 characters) and the spaces to extract the next word. If it is empty, or is neither
   `STATUS` nor `PRIORITY`, it prints a syntax error.
2. It reads `todo.txt`. If it is empty, it prints `No tasks to sort.`
3. Determining the type of sort:
   - If `STATUS`:
     - Pass 1: copy the lines whose character after the second `|` is `P`.
     - Pass 2: copy the lines whose character after the second `|` is `D`.
   - If `PRIORITY`:
     - Pass 1: copy the lines with `!` (after the third `|`).
     - Pass 2: copy the lines with `*`.
     - Pass 3: copy the lines with `.`.
4. **Common final pass for both sort types:** a last pass appends to the end of `sort_write_buf` every line that does not
   have a valid structure (not enough `|` characters).
5. The content of `sort_write_buf` is written back to `todo.txt`.

**Logical routines**

- `.do_sort_pass`: this subroutine takes two important inputs: the target character (`P`, `D`, `!`, `*`, `.`) and the
  target pipe number (1 for status, 2 for priority). After receiving them it walks `sort_read_buf`, skips empty lines and
  validates the structure of non-empty lines. If the target character is found in the right position, the whole line is
  copied into `sort_write_buf` with the `rep movsb` instruction.
- `.copy_malformed_pass`: this subroutine runs after all the sorting passes. It finds the lines that lack a valid
  structure (not enough `|` characters) and appends them to the end of `sort_write_buf`, to prevent incomplete data from
  being erased.

**Variables in `.data`**

- `sort_success_msg`, `sort_syntax_err`, `sort_empty_msg`: the strings for the success message, the syntax error and the
  empty-file message.
- `sort_kw_priority` and `sort_kw_status`: keywords used for string comparison with the user input to determine the type
  of sort.

**Variables in `.bss`**

- `sort_arg_buf` (16 bytes): temporary buffer for the argument extracted from the user (the word `STATUS` or `PRIORITY`).
- `sort_write_buf` and `sort_read_buf` (4096 bytes each): buffers for reading the initial `todo.txt` and building the new
  sorted version.
