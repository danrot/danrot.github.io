---
layout: post
title: Finding used values of XML attributes using the command line
excerpt: I was refactoring a feature and wanted to know which options were used for a certain attribute in a XML file. I decided to level up my CLI skills for that.

tags:
    - cli
    - xml
    - regex
---

A few weeks ago I was working on a
[Sulu Pull Request to support filtering lists](https://github.com/sulu/sulu/pull/5035). We've already had a very
similar feature before that, which was (and still is) configured in a XML file. Each defined filter had a type, also in
the previous implementation. In order to refactor this, it would have been very helpful to know what the previously
available type options were. The old filter implementation used to be defined something like this:

```xml
<property
    name="name"
    visibility="always"
    searchability="yes"
    filter-type="string"
    translation="sulu_contact.name"
>
    <field-name>name</field-name>
    <entity-name>%sulu.model.account.class%</entity-name>
</property>
```

The interesting part here for me was the `filter-type` attribute on the `property` node. To get an overview I wanted to
get a list of all values, that have been used for this attribute.

Since I am using [neovim](https://neovim.io/) as an editor, I could not use any fancy IDE functionality for that. And
to be totally honest, even back when I used PHPStorm, I only used "Search in path" with plain string values. I might be
wrong, but I guess most people don't use a lot of the stuff PHPStorm offers, which is also the reason I stopped using
it. It almost feels like bloatware with a lot of stuff I never needed, and it is much slower than using e.g.
[neovim](https://neovim.io/), which allows me to free resources for my important tasks. Apart from that I am not even
sure PHPStorm would have been able to help me with the task at hand.

However, I didn't have to check, because I didn't want to use it anyway. So I decided to level up my CLI skills a bit.
It turns out that this task can be solved with some pretty standard commands on the Linux CLI.

*Note: If you want to follow along the upcoming commands, you can do so using
[this commit of Sulu](https://github.com/sulu/sulu/commit/dd99ea0f0ee8b5afc7995f79ac6fd3c3bced5027).*

First of all I needed to find all files configuring these lists I have mentioned before. Fortunately their location is
the same within each of Sulu's [Bundles](https://symfony.com/doc/current/bundles.html) (something like plugins for the
[Symfony Framework](https://symfony.com/)). Therefore I was able to use the `find` command to list all of these files:

```bash
$ find src/Sulu/Bundle/*/Resources/config/lists/ -name "*.xml"
```

The first parameter of the `find` command lists all the folders that should be searched. The asterisk in there is a
placeholder, which means this lists all the `Resources/config/lists` folders within every folder under
`src/Sulu/Bundle`. Then the `find` command will return every file within this folder that matches the pattern passed
via the `-name` argument. So the above command will return all XML files configuring the lists in Sulu.

But having this list of files is just the first step. Next I had to retrieve all the `filter-type` attributes being
used in these lists including their values. Luckily the `find` command accepts a `-exec` argument, which takes a
command and executes that command for every single file it receives. Everything starting from the `-exec` flag until
a semicolon will be interpreted as the command that should be executed for every file. Within the command the string
`{}` can be used to refer to the file that command is currently executed for. Mind that both the `{}` placeholder and
the semicolon have to be passed as strings or need to be escaped, since your shell might interpret these characters in
a different way otherwise

So to summarize the above paragraph in an example, this is what you would have to enter in your shell in order to
output every file with a `File:` prefix:

```bash
$ find src/Sulu/Bundle/*/Resources/config/lists/\
    -name "*.xml"\
    -exec echo "File: {}" \;
```

*Note: The `\` at the end of line allows to split a command in several lines, so the above examples can be easily
copied*

Now that we have found a way to execute a command for multiple files we need to find the command we want to execute for
them. For the purpose of finding a string within a text the `grep` command is a very popular choice. It executes a
search using the passed regular expression on a file and prints all the lines highlighting the matches. So if we e.g.
try to find all lines in the `contacts.xml` file containing a `filter-type` attribute with some value we could do
something like this:

```bash
$ grep 'filter-type="[^"]*"' contacts.xml
```

The `grep` command takes a regular expression as the first argument. In this regular expression we are looking for the
exact match `filter-type="`, followed by a arbitrary number of characters not being a quote (the square brackets
defines a set of characters, whereby the `^` means everything except that character and the `*` stands for any number
of them) being finished with another quote. The other argument is the name of the file we want to search in. If you
execute this command you will realize that always the entire line containing the regex is printed, which makes it a
little bit hard to further analyze that data, because every printed line looks a bit different. What I actually wanted
was to get only the matched string without the rest of the line, because then I could apply even more commands to the
result in an easy manner. Thankfully there is the `-o` option, which does exactly that: return only the part that
actually matched and avoid printing the rest of the line:

```bash
$ grep -o 'filter-type="[^"]*"' contacts.xml
```

That returns all occurences of the regex, without the rest of the line, but only for a single file. So let's combine
that command with the `find` command from above:

```bash
find src/Sulu/Bundle/*/Resources/config/lists/\
    -name "*.xml"\
    -exec grep -o 'filter-type="[^"]*"' "{}" \;
```

Nice! Now a list where all entries have the form of `filter-type="<filter-type-value>"`. That's something we can
continue to work with. The only problem is that the list is a little bit tedious to read, because it shows an entry for
every occurence, whereby I only wanted to have a single line for every value. There is a command called `uniq`, which
would remove all repeated lines. But only if they are following directly to each other, which is currently not the
case. So by using the `uniq` command we would retrieve less lines, but there would still be some duplicates. So the
data needs to be sorted before the `uniq` command is applied, which can be done by the `sort` command. Both of these
commands support several different options, but I don't care too much about the order of the result, so they are not
really important.

In order to use the output of the `find` command as the `input` of the `sort` command the pipe operator (`|`) can be
used. This allows the `sort` command to sort the output of the `find` command. Afterwards we can use the pipe
operator to pass this sorted data to the `uniq` command, which will then omit the lines appearing multiple times.

```bash
find src/Sulu/Bundle/*/Resources/config/lists/\
    -name "*.xml"\
    -exec grep -o 'filter-type="[^"]*"' "{}" \;\
    | sort\
    | uniq
```

And that's it! This command will show a list with all occurences of values appearing in the `filter-type` attribute a
single time, no matter how many times the value occurs. With this helpful information I could make better decisions
when continuing to refactor this functionality.

 I think this is a kind of approach I want to try more often in the future. The command line is super comfortable to
 use once you've got the hang of it, and this knowledge can be easily applied in different situations, if you have
 understood the basics of the shell, e.g. the pipe operator.

 PS: Maybe there are better tools available to do the job (could e.g. think about using XPath), but this approach can
 also be used with other file formats, that's why I decided to dig a bit deeper here, and I would have had to
 investigate how to solve this with XPath as well.
