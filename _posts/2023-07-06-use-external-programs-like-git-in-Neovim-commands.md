---
layout: post
title: Use external programs like git in Neovim commands
excerpt: Bla

tags:
    - neovim
    - vim
    - git
    - cli
---

I have been an enthusiastic (Neo)vim user for years now, and until today I love to improve my setup and often learn one
or the other trick that makes me more efficient, even if it is just by a little bit. Therefore I want to start writing
about that as well.

Recently I started using the command mode of Neovim a lot more, and do not stop at the most basic commands like `:w` to
save a file or the infamous `:q` for exiting it (why would you want to exit such a great program anyway). **What I find
particularly interesting is the fact that you can use any command installed on the machine in the command mode by
starting the line with a bang.**

I usually have an instance of Neovim running within the awesome [kitty terminal](https://sw.kovidgoyal.net/kitty/),
along with a few other windows running shells. These other shells I use to run all kinds of commands, like `git status`,
`docker compose up`, etc. I do not plan to get rid of those windows, since the main purpose of an editor is not to run
commands, for which reason it can feel clunky sometimes. So while it is possible to execute `ls` in Neovim and get the
directory listed, it does not feel right to me.

However, there are some commands, mainly those without any meaningful output at all, that are more comfortable to
use from within Neovim. **This is especially true for commands that require some input Neovim can deliver, like the path
of the currently opened file, which can be inserted using the `%` placeholder**.

E.g. I am still not using a GUI for Git, since I feel much more efficient this way. But staging a specific file using
the `git add` command always felt a bit tedious, since the path has to be passed as an argument. Since this command
makes use of the file path and has no output, I started to execute that command directly in Neovim instead of typing it
into the shell, which was cumbersome even with tab completion.

To do so, I type the following when the file I want to stage is currently opened in normal mode:

```plaintext
:! git add %
```

This way the currently opened file will be staged, without providing the entire file path! Doing this feels so natural
that installing a separate plugin for Git handling almost feels like a waste of resources (at least if you only need it
for adding files to the staging area).

There is another use case I am using quite often lately: If I am currently editing a test I usually want to execute it
right afterward, ideally only this single test file instead of my entire suite. Most test runners support that by
passing the path of the test file as an argument. But again, doing so felt quite tedious to me. Fortunately, that task
can also be improved by using a Neovim command:

```plaintext
:! echo % | pbcopy
```

Here the built-in `echo` command is used to output the current file path using the `%` placeholder to `stdout`, which
will then be piped to `stdin` of the `pbcopy` command. `pbcopy` comes with macOS, and will put anything it gets via
`stdin` into the clipboard. So instead of typing the command for my test runner and tediously passing the file path as
an argument I can now only type the command of the test runner and pass the test file path by pasting it from the
clipboard using `command+v`.

In addition, commands like that can also be used to alter the text in the editor. This is different from the uses
before since commands need a meaningful output for that to make sense, but it shows how extremely powerful that concept
is. An example of that is the following command, which inserts the current date using the `date` command from the
operating system:

```plaintext
:read !date
```

`read` is a Neovim command, that can be used to insert text at the current cursor position. And this `read` command can
also be used in combination with any operating system command like `date`.

It is also not only possible to insert text, but also to manipulate existing text using such commands. Imagine you have
a list of numbers in your editor, that you would like to sort. Instead of building some special functionality in Neovim,
it is quite easy to use the already existing `sort` command. This can be done by marking the numbers using the visual
mode (pressing `v` in normal mode) and then execute the following command (do not worry, the `'<,'>` will be inserted
automatically):

```plaintext
:'<,'>! sort -n
```

This shows that it even is possible to pass any arguments to the shell commands.

I love this about this entire ecosystem since I always get excited when different systems can be combined so easily. Do
you have any other ideas on how to use this approach?
