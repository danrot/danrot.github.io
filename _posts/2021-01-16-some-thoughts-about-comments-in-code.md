---
layout: post
title: Some thought about comments in code
excerpt: Comments in code are quite often a code smell. Let's see what is suboptimal about comments and talk about some strategies to avoid them.

tags:
    - php
    - programming
    - documentation
    - dry
---

["Don't repeat yourself"](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) is such an important and widely taught
concept in programming, that it has its own acronym (DRY).

> Every piece of knowledge must have a single, unambiguous, authoritative representation within a system
>
> --- [Wikipedia](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)

DRY is a very powerful idea, and avoids a lot of issues, like having to fix the same bug in multiple places, because
the same code has been duplicated. Many voices say that it is often overused leading to a wrong abstraction, and I tend
to agree with that statement.

> duplication is far cheaper than the wrong abstraction
>
> --- [Sandi Metz](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction)

People often overdo the DRY principle by building abstractions the first time a problem occurs. Instead, the problem
should not be abstracted before it has occurred multiple times, since it might easily lead to a wrong abstraction that
might not live up to its responsibilities and ultimately causing more problems than it solves. There are already some
principles like WET (Write everything twice) and AHA (Avoid hasty abstractions) that kind of contradict the DRY
principle respectively limit its applicability.

While I welcome the recognition of DRY overuse in many situations, I think this principle tends to be underused when it
comes to code comments, which is the topic of this blog post.

## Comments often violate the DRY principle

In their fantastic book *The Pragmatic Programmer* David Thomas and Andrew Hunt have coined the DRY principle and they
have explicitly listed that comments are a possible violation of this principle. When people are learning to code, they
often get taught that good code needs lots of comments, which is absolutely not true in my opinion. Very often good
code that is self-explanatory does not need any comments at all and if it does, the **comment should describe why it
has been implemented this way** instead of just repeating what the code already says.

[My favourite stack overflow question of all time deals with code
comments](https://stackoverflow.com/questions/184618/what-is-the-best-comment-in-source-code-you-have-ever-encountered)
and lists some really good examples of how not to do it (especially if you skip the funny ones, which unfortunately for
this blog post are the majority).

There is one [very obvious example](https://stackoverflow.com/a/185308) of a bad comment:

```php
return 1; # returns 1
```

This is a very obvious violation of the DRY principle, whenever the return value changes, the comment also has to be
updated. But there are other not as obvious examples:

```php
$i++; // increase by one
```

This is only acceptable as an explanatory comment in teaching material, but it should never make its way to a
production codebase.

## The fall of doc blocks

Especially in languages with weak typing documentation comments are very popular. Since these languages often don't
allow to specify types in code, people have invented ways to move that information to comments, which allows for a
better understanding of the code when reading it. The alternative would be to read the code and try to find out based
on how these variables are used what type needs to be passed. Popular libraries include [PHPDoc](https://phpdoc.org/)
and [JSDoc](https://jsdoc.app/).

```php
/**
 * Adds two numbers
 *
 * @param int $a
 * @param int $b
 */
function add($a, $b) {
    // ...
}
```

Especially the `@param` made a lot of sense because the code itself does not expose that information in a very
accessible way. But
[recent PHP versions improved the type system a lot](https://www.php.net/manual/en/language.types.declarations.php) and
also in JavaScript technologies allowing to add type information like [TypeScript](https://www.typescriptlang.org/) get
a lot more popular ([compared it to Flow in another article](/2020/06/05/typing-in-javascript-flow-vs-typescript.html)
), which makes these doc blocks obsolete in many cases.

```php
function add(int $a, int $b) {
    // ...
}
```

As a bonus, these type systems will also yell at you if the type is not correctly set, something a pure comment cannot
really help with. So adding another comment just with the type annotation would duplicate that information with no real
value unless the parameter is explained in more detail.

## Comments tend to be ignored by developers too

The reason comments exist is to allow adding additional information to the source code in natural language. Whatever is
added as a comment will be ignored by the compiler or interpreter. **Developers know that, so many of them learned to
ignore them to a certain degree.** That's especially true if they have ever worked with a codebase that contained
outdated comments. I am always very skeptical when reading comments and double-check with the actual implementation if
the statement of the comment is true because I have experienced too often that the code didn't behave as the comment
suggested.

Again, there is an answer in the already mentioned [Stack Overflow question](https://stackoverflow.com/a/389723):

```php
/**
 * Always returns true.
 */
public boolean isAvailable() {
    return false;
}
```

That might look like a really stupid example because it is so terribly obvious. But I totally believe that something
like this can easily happen in a real codebase. Since developers tend to ignore code as well, it is not very unlikely
that they don't update the comment when changing the code for some reason.

The worst thing is that the above example is not even that bad, because after a second you'll realize that the comment
is wrong. More detailed errors in a comment are much harder to recognize because more complex code usually justifies
comments, but they are only helpful if they are actually up to date. If developers don't read comments in the first
place, they are at the same time much more likely to not update them if they change something, giving them again less
reason to believe in them. I would say this is a vicious circle.

## Comments should add something

As already mentioned more complex code often justifies comments, at least if they describe reasons or thoughts that are
not obvious from just looking at the code. But if it is considered very strict, this is already a violation of the DRY
principle, because the comment needs an update too when the code changes. But it might be worth the tradeoff if the
code is hard to understand.

A rule I am following is that a comment should not just repeat what the code is already saying. Another phrasing would
be to say that comment must always add values, that would be missing if they weren't there. Just recently there was a
discussion in Austria about
[some JavaScript code for a covid-19 vaccination forecast](https://twitter.com/botic/status/1349128186576121857)
because the code just seemed to make up some numbers. But the more interesting part of that code was the usage of
comments in it:

```javascript
if(now.hour() < 6) {
    estimated = ausgeliefert; // hour is before 6am
} else if(now.hour() > 17) { // hour is after 6pm
    // ...
}
```

The first comment basically just repeats what the line before is doing. If we need to describe what the line
`now.hour() < 6` is doing, then we would basically have to comment every single line in our code. The same is partially
true for the next comment. It was probably written to indicate that although the code says `now.hour() > 17` does not
include times like 17:01. It might be a little bit better than the first comment, but I still don't think that it is
worth the tradeoff of duplicating the same information in two different places.

Another tradeoff is the doc block of the `add` function from above. As long as the `int` type hints are not part of the
code itself, it makes sense to add this information, because it is much easier to find out what types have to be passed
this way. If that information is not there, it might be quite hard and even need some debugging to be sure about the
types that the function accepts. I guess this improvement in developer experience justifies the potential risk of the
comment being outdated. But as already said above, the latest PHP versions support the type hints in code, making the
comments obsolete and guaranteeing the type of the variable.

## Good naming can often replace comments at all

Finally, I want to show some code, that might get rid of some comments by writing it in a self-explanatory way. This
makes the code more obvious to read and since it is real code and not just comments, it is much less likely that
developers won't read it.

Let's start with the JavaScript example from the previous section. We've already said that the first comment is kind of
unnecessary, so we can safely omit it. The second comment kind of had a point because it was explaining in a hidden way
that the hour has to be after 18:00, and even though 17:01 is after 17:00, it would not be accepted by the `if`
statement. Another way to make this more clear is to use the `>=` operator instead. It removes that ambiguity and reads
nicer.

```javascript
if(now.hour() < 6) {
    estimated = ausgeliefert;
} else if(now.hour() >= 18) {
    // ...
}
```

Now the code itself is more clear and the comments could be removed, just by using a different operator.

The other two examples I am showing are real-world examples I've run into during my work as a software engineer. The
first one is an `if` statement, that tries to find out if a given node represents a document that is a new one or if it
has already existed before. The logic to do so was a bit cryptic, so it made sense to use a comment to explain what was
happening here:

```php
// Check if the document is a new document
if (
    !$node->hasProperty(
        $this->propertyEncoder->encode(
            'system_localized',
            StructureSubscriber::STRUCTURE_TYPE_FIELD,
            $event->getLocale()
        )
    )
) {
    // ...
}
```

A very easy way to avoid this comment, is to store the result of the `if` statement in a separate variable and give it
a meaningful name:

```php
$isNewDocument = !$node->hasProperty(
    $this->propertyEncoder->encode(
        'system_localized',
        StructureSubscriber::STRUCTURE_TYPE_FIELD,
        $event->getLocale()
    )
);

if ($isNewDocument) {
    // ...
}
```

This avoids the need for the above comment, and developers cannot really skip the variable name, because it needs to be
referenced later. The comment would have been written in gray by the IDE, kind of telling the developer that these
lines don't really matter. By skipping reading that part of the code, it is also more likely that the comment does not
get updated when the code changes.

*It would be even better if this check would be part of a class so that it could be called like `$document->isNew()`,
but that's beyond the scope of this article.*

Another example I've stumbled upon is the following code:

```php
// remove the "sec:role-" prefix
$roleId = \substr($property->getName(), 9);
```

The above code will remove the prefix `sec:role-` of a string to retrieve the ID based on the name of a property. The
code works, but the number `9` is a so-called magic number, so it needs some explanation, so it somehow feels natural to
just add a comment afterwards. Sometimes constants are used to give such magic constants a name that better explains
what it should be doing. But in this very specific example, there is also a different solution.

```php
$roleId = \str_replace('sec:role-', '', $property->getName());
```

This example does not make use of code that counts the number of characters, but we are replacing the `sec:role-`
prefix with an empty string. This way it is clear that the `sec:role-` prefix is removed, without the need of a comment
violating the DRY principle.

I really like finding ways to write code in a way that better explains itself. Very often these changes are really
subtle, but they change the way code is read fundamentally and avoiding comments altogether. I hope that these examples
helped you to find some motivation to do so too!
