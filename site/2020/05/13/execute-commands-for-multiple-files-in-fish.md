---
layout:
    post: true
title: Execute commands for multiple files using fish
excerpt: Quite often I want to execute the same command for multiple files. It is quite easy to achieve that using the fish shell, once you get the hang of it.
tags:
    - cli
    - fish
    - linux
---

Recently I have downloaded some submissions from a course I am currently giving. Luckily the tool being used allows to
download an archive with all submissions at once, but unfortunately the structure of the archive is not really handy. It
contained a folder for every student, and in this folder there was another zip archive, which contained the actual
submission of the given student.

In addition to that every single archive contained a JavaScript project, in each of which I had to execute
`npm install` in order to test the submission afterwards. So I could either go into each folder, unzip the archive and
install the NPM packages for each and every one of them. Or I could take some time, and figure out how to unzip all
archives and install the required packages with two small command line scripts.

Of course I chose the latter!

First of all I had to find a glob that matches all the files I want to execute the command (`unzip` in my case) for. The
`ls` command is great for testing this:

```plaintext
ls */*.zip
```

`ls` is usually used to list the content of entire directories, but also allows to list files being passed to it. This
is really useful in combination with the
[wildcards the fish shell provides](https://fishshell.com/docs/current/index.html#wildcards). `fish` tries to match the
`*/*.zip` expression to as many files as possible, whereby the `*` can be a string of any length not containing `/`,
which is the folder delimiter in linux. That means it will find any arbitrarily named file ending in `.zip` being
located directly in a sub folder of the current directory. So the above command returned file names like
`erika_mustermann/submission.zip` and `john_doe/assignment.zip` for me, which indicated that I was on the right track. I
always start tasks like that this way, because I want to make sure that I am not accidentally executing the commands for
the wrong files.

Next step: Figure out how to use the [`for` loop in `fish`](https://fishshell.com/docs/current/cmds/for.html). I still
prefered to play it safe, so I decided to only output the names of the files using the `echo` command within the `for`
loop.

```plaintext
for file in */*.zip;
    echo $file;
end
```

Basically the `for` loop in `fish` is a simple `for .. in` construct, whereby the name after the `for` is being used as
the variable name (mind that it is defined without a prefix, but when accessing it a `$` is required), and the part
between `in` and `;` is the expression that is being looped over, which is every file that matches the glob in our case.
Other than some differences in whitespaces the output should be pretty much the same as in the previous `ls` command.

So I knew that the `for` loop was receiving the correct values and I could start writing the actual command I want to
execute for all of these files. I've ended up with the following:

```plaintext
for file in */*.zip;
    unzip $file -d (dirname $file);
end
```

The `unzip` command takes the name of the archive file you want to extract. The only problem is that it will extract the
archive's content in the current directory instead of right next to itself. Fortunately the `unzip` command comes with a
`-d` option, that allows to specify the directory you want the archive to be extracted to. However, this option expects
a directory, not a file. All I've got until now is the file name of the archive, but thankfully `dirname` exists as
well. That's a command that will remove everything after the last `/` in the given string, including the `/` itself. So
it is a great utility to get the parent directory of another file or directory. I use that command in combination with
[fish's command substitution](https://fishshell.com/docs/current/index.html#command-substitution), which allows me to
execute another command and use it as parameter of an outer command. That is done by putting the inner command in
paranthesis.

The above command unarchived all zip files right where there are located. But some of the students added another root
folder in their archive, and others didn't. So the structure was not always the same, but I still wanted to run
`npm install` for all of them at once. Therefore I decided to use another `for` loop with a different glob. The `**`
wildcard is similiar to the `*` wildcard, but with one important difference: It also includes `/`, meaning that it
matches an arbitrary number of sub folders, not just a single one. This way it does not matter if another folder has
been added as root in the archives.

In addition to that I also make use of the fact that multiple commands can be used within a `for` loop if they are
delimited by a `;`.

```plaintext
for file in **/package.json;
    cd (dirname $file);
    npm install;
    cd -;
end
```

This loop finds all `package.json` files in any of the current sub directories, changes to the containing directory of
the file by again using the `dirname` command with the `$file` variable. Afterwards `npm install` is executed to
install all the dependencies, and once that is finished it goes back to the previous working directory (that's what the
`-` stands for).

For some reason I was always a bit hesitant when using loops in the command line. Somehow the command line always felt
to me like something to which I enter a single command and get a result in return, which is a pretty simple protocol.
Using stuff like pipes still felt ok to me, but a loop might need to be broken into multiple lines quite quickly, which
does not feel natural to me. But it is probably a much bigger time saver than other features of shells, so I checking
them out is highly recommended!
