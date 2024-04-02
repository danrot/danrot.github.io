---
layout: post
title: Finding all HTML tags in a project not being self-closed
excerpt: For some refactoring I needed to find all HTMl tags not being self-closed. I decided to use regular expression for that, and this is what I came up with.

tags:
    - html
    - vue
    - regex
    - cli
---

I am currently working on upgrading an existing [Vue](https://vuejs.org/) project from version 2 to 3, which involves
[quite some breaking changes](https://v3-migration.vuejs.org/breaking-changes/). I don't want to go into the details,
but at one point it was useful to find all elements of a certain Vue component that were not self-closed. In this
specific, case it was about a `base-input` component. The following cases were of interest to me:

```html
<base-input value="Some text"></base-input>
<base-input disabled>Some text in a slot</base-input>
```

However, the following were not:

```html
<base-input value="Some text" />
<base-input disabled />
```

There were quite some occurrences of this component in the entire project, therefore just searching for `base-input` was
not going to cut it for me. Instead, I decided to use regular expressions resp. regex with
[ripgrep](https://github.com/BurntSushi/ripgrep). After installing ripgrep it provides a `rg` command line tool.

The following solution worked for my use case:

```bash
rg --multiline '<base-input[^>]*[^/]>'
```

Let's break it down:

1. The `--multiline` flag will make sure that this pattern is also matched across multiple lines, i.e. the match can
   contain line breaks.
2. The `<base-input` will be searched for literally, i.e. this exact character sequence.
3. With `[^>]*` an arbitrary amount (that's what `*` stands for) of characters not being `>` will be matched.
4. After that, there must be at least one character not being a `/`, which would indicate a self-closing tag.
5. Finally, the `>` finishes the tag.

**Although this works for the above examples, it is not a universal solution to the problem.** It does for instance not
match the following cases:

```html
<base-input></base-input>
<base-input value="Some > text" />
```

The first line will not be matched, because there must be at least one character not being `/` after the `<base-input`
literal. Fortunately, that was not a problem for me, since I knew that using that component without attributes does not
make any sense, so I could ignore that case.

The second line will match although it shouldn't, since it recognized the `>` within the quotes as the end of the tag.
This will result in a false positive, but that was also fine for me since this did not occur quite often in the code
base.

Unfortunately, it is not even possible to write a full HTML parser using regular expressions, even though so many people
ask about this on Stack Overflow that they've decided to make this part of their [regular expressions
FAQ](https://stackoverflow.com/questions/22937618/reference-what-does-this-regex-mean/22944075#22944075). **But that
should not stop you from using regular expressions to do quick one-off tasks such as finding some occurrences in a big
code base if you know the limitations and how they might affect the results.**
