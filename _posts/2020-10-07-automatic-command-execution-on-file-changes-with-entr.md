---
layout: post
title: Automatic command execution on file changes with entr
excerpt: Sometimes you want a command to be automatically executed as soon as a certain file changes. There is a small tool called entr, which helps with that.

tags:
    - cli
    - linux
    - php
    - testing
    - markdown
    - presentations
---

**One of the best features of [Jest](https://jestjs.io/) (the JavaScript testing library) is its
[watch mode](https://jestjs.io/docs/en/cli#--watch)**, which can be activated by adding the `--watch` flag to the call
of the `jest` command. So if the `jest` executable is in your current path, you can call it like that:

```bash
jest --watch
```

And what this simple flag does is absolutely amazing. **Instead of just executing all the tests and shut down, Jest
will execute only the tests being affected by the currently not staged changes of your git repository.** That means you
don't have to execute all the tests all the time, which will result in much less load on your machine. At the same time
only the necessary tests run and finish much sooner, which will result in a much better developer experience.
Additionally, **Jest will watch all your files, and rerun your tests as soon as a file within your codebase changes.**

## A watch mode for PHPUnit

Actually I was so fascinated by this feature, that I wanted to have something similar for
[PHPUnit](https://phpunit.de/), my PHP testing framework of choice. Unfortunately I did not find any built-in solution,
but I found **another interesting generic-purpose tool called [entr](http://eradman.com/entrproject/)**. Based on this
I could build something I would call a **poor man's watch mode**. Just recently I had to resolve a merge conflict in a
PHP file; luckily the error was also caught by a unit test. Since the unit test failed, and I knew which file was
causing the error, it was easily possible to **rerun the unit test everytime the content of that PHP file changed**.

```bash
ls path/to/source-file.php | entr phpunit --filter=path/to/test-file.php
```

`ls` in the above example will only return the path to `source-file.php` and pass that value as input to the `entr`
command. The `entr` command will add a file watch to this file, and execute the command it gets passed everytime
`source-file.php` changes its content. That's already a poor man's watch mode! And it was really useful in that case,
because I didn't have to change to another terminal everytime I wanted to run the tests. I just had two terminals open,
and when I changed the content of `source-file.php` in order to resolve the conflict in one terminal, the other
terminal automatically **ran the tests without any manual instruction from my side**.

But the `ls` command is only the easiest way to get a list of files `entr` should watch. A more powerful alternative is
the `find` command, that is also distributed with almost every linux installation. So we can use the following command
if we want to run the entire `phpunit` testsuite when any file ending with `Test.php` is updated:

```bash
find . -name "*Test.php" | entr phpunit
```

Mind that this might not make a lot of sense if you have a huge test suite, since waiting an hour after everytime you
touch a PHP file would be a waste of time (so is waiting too long for your tests, so you might refactor that suite
anyway).

You can even use other powerful tools like [`ack`](https://beyondgrep.com/) to get the list of files `entr` should
start watching. If you e.g. want to run your entire test suite whenever a file is changed, which instantiates a `Media`
object (again, not sure this is a very good use case, but I still want to show how it would work, so that you
understand it better) your command would look like this:

```bash
ack "new Media()" -l | entr phpunit
```

*The `-l` flag of the `ack` command will only list the files containing this content, not the content itself. It is
necessary, because otherwise `entr` get more than just a list of entries, and it wouldn't be able to handle that.*

Of course you can also combine this new knowledge with any of your previous knowledge of your shell. But keep in mind
that this is still not as powerful as Jest's watch feature. That is because Jest can analyze the JavaScript code, and
will even be able to tell which files are importing a changed file, and include that information when finding the tests
that are affected by this change.

## Reuse that watch mode with other commands

Since we have found now a more generic solution to this problem (which comes with the just mentioned downsides) **we
are able to also reuse that command in other situations**. Something that I found very helpful is to automatically
create new HTML output when I am building one of my
[markdown presentations](/2020/03/28/creating-highly-customizable-html-presentation-with-markdown-and-pandoc.html). All
I have to do to make this work is to write a command like this, which will then run and create a new HTML output
whenever my `slides.md` file changes:

```bash
ls slides.md | entr make html
```

So while this approach is not as powerful as having a watch mode fully integrated in some other tools, I still like to
have it in my toolbelt, **since I can apply it to many different situations in which a watch mode might not be
available**.

If you are curious now and you want to play with `entr`, you can easily install it in ArchLinux using `pacman`:

```bash
pacman -S entr
```

I am sure that other linux distributions also have an `entr` package, so check it out and happy entring!
