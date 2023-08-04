---
layout: post
title: Typing in JavaScript - Flow vs. TypeScript
excerpt: There were two choices for static type checking in JavaScript - Flow and TypeScript. TypeScript is much more popular nowadays, but let's compare them anyway.
tags:
    - javascript
    - flow
    - typescript
    - typing
---

At [Sulu](https://sulu.io/) we have decided to use [Flow](https://flow.org/) for static type checking, and I am still
convinced that it was the correct decision back then. However, today [TypeScript](https://www.typescriptlang.org/)
seems to be the [much more popular choice](https://www.npmtrends.com/flow-bin-vs-typescript). This claim can also be
supported by earlier [blog posts](https://mariusschulz.com/blog/typescript-vs-flow) and
[presentations](https://djcordhose.github.io/flow-vs-typescript/2016_hhjs.html#/) being more about what to choose,
whereby [more recent ones](https://sobolevn.me/2019/03/from-flow-to-typescript) are about how to switch. So I think it
is time to reconsider that decision, therefore I am going to compare these type checkers in this blog post.

## What is static type checking?

Static type checking has the **goal of finding errors before you even run your code**. This will catch quite a bunch of
errors for you, and helps a lot to deliver higher quality code. Let's have a look at a short example:

```javascript
console.log(5/"5");
```

This code is syntactically correct, so JavaScript will not complain about this, until it executes that line of code.
Since it is pretty obvious that you cannot divide a number by a string, you might say you are not doing that anyway,
but imagine that the value of `"5"` is stored in a variable, and the value of that variable is not completely clear,
because it is determined in a 100 lines of code. In that case it would be quite easy to mess this up in some way,
without immediately realizing it. **A static type checker would tell you about the error at the moment you introduce
it**, and you are much more likely to know what's wrong than when finding out about this error at runtime a year later.

Now there are different ways on how to apply static type checking. Many **compiled languages do this during their
compilation step**, which means that the program does not compile at all if you get any type errors in your project.
This is a valid approach, and you will also know about the error very soon. But you are losing the opportunity to
quickly test doing something in a slightly different way, because you might have to adjust a huge amount of types
before you can even compile the program.

JavaScript is not a compiled language, therefore it can only check the code when it is being interpreted, i.e. at
runtime. And that's exactly where TypeScript and Flow jumps in: These are tools that allow to annotate your JavaScript
code with type annotations and check based on top of them if everything can work as expected. However, you are not
writing pure JavaScript anymore, but instead you have to somehow turn that into pure JavaScript in order for browsers
to understand your code. TypeScript comes with its own compiler for that, whereby Flow just relies on Babel to get rid
of the annotations for you. TypeScript needs that compilation step for certain features it implements, because strictly
speaking it is more than just a static type checker.

The advantage of the latter approach is that **you can adjust the code in a way that types will fail**, but you can
ignore that for the moment, if you are just trying to quickly test something. In a compiled language you would have to
fix all the type errors first. Now you can say that the program won't run anyway as expected (although that is not
completely true, because you might use it in a way that the type errors don't matter), but at least it can run until a
certain point, where you might be able to already do a `console.log` to check on something. That's something I really
enjoy.

On a sidenote, there are also languages like PHP, which have improved their type system over the last years
significantly, but it still feels a bit weird. PHP comes with the possibility to annotate your code with types in many
different places, but it does not allow to check these errors before runtime. So you can e.g. define in a function that
the parameter must be a string, but if you are calling the function with a wrong type, you will not realize that before
this code is being executed, in which case you will get a runtime error. In my opinion this is the worst of both
worlds, because you can't tell about the errors before actually running the code, and it doesn't allow you to quickly
test something with different types. To be fair, there are tools like [PHPStan](https://phpstan.org/) and
[Psalm](https://psalm.dev/) that work in a similar fashion than TypeScript and Flow, but PHP will still not allow to
execute your code with wrong types.

## Why did we decide to use Flow?

We started the rewrite of Sulu 2.0 in mid 2017 and decided to use Flow as our static type checker. It was clear to me
that we have to use a static type checker, since it will allow us to discover bugs much sooner as if we wouldn't use
one. Back then we had the choice between Flow and TypeScript, but TypeScript had a few downsides.

First of all we felt that TypeScript was more like a separate language, because it also adds a few features beyond type
checking, like [`const enum`](https://www.typescriptlang.org/docs/handbook/enums.html#const-enums). This is also the
reason TypeScript needs a compiler: Features like this require the code to be transpiled to something else, and it
cannot only be simply removed. However, after also playing a bit with TypeScript I have to say that these features are
optional and in practice it is not as cumbersome as I would have thought. Also, Flow isn't standard JavaScript either,
although it might be (negligible) closer to it. But it would be easier to turn away from Flow, because "compiling" is
simply removing the type annotations, so the code would even keep its readability and the compiled version could be
used instead of the annotated one.

More importantly, **TypeScript had its own ecosystem**. E.g. there was no way to integrate TypeScript with
[ESLint](https://eslint.org/), but they had their own tool named [TSLint](https://palantir.github.io/tslint/). Babel
was also not supported, so you couldn't easily add any new JavaScript features, but had to wait for the TypeScript team
to implement them in their compiler.

**While these were valid reasons not to use TypeScript when we started in 2017, I wouldn't consider them valid reasons
anymore today.** TSLint has been deprecated in favour of
[typescript-eslint](https://github.com/typescript-eslint/typescript-eslint), an integration of linting for TypeScript
into ESLint. This is awesome, because it allows to use the entire ESLint ecosystem in combination with TypeScript, like
one of my favourite ESLint plugins: [`eslint-plugin-jsx-a11y`](https://github.com/jsx-eslint/eslint-plugin-jsx-a11y).
[Babel can now also be used for TypeScript](https://iamturns.com/typescript-babel/), although this way of using
TypeScript is not feature complete. But still, you are able to easily use e.g.
[CSS modules](https://github.com/css-modules/css-modules) now in combination with TypeScript and it allows for an
easier integration of React.

## Comparing caught errors and error messages

When comparing the default settings and shown error messages from TypeScript and Flow, I am still in favour of
Flow, although that does not seem to be a very popular opinion anymore... Let me explain that in a few examples:

```javascript
let value = null;
value.toString();
```

It is pretty obvious that the above code will fail at runtime, because a `toString` method is not existing on a value
of `null`. So I would expect a static type checker to warn me about errors like this. TypeScript fails to do so, unless
it is called with the `--strictNullChecks` parameter on the command line (still wondering why that is not the default).
But even if that option is activated to make TypeScript recognize that change, I like the error message provided by
Flow better:

![Cannot call value.toString because property toString is missing in null.](/images/posts/flow-null-to-string.webp)

Checkout the TypeScript error message in comparison:

![Object is possibly 'null'.](/images/posts/typescript-null-to-string.webp)

Flow provides more helpful information to locate the actual error. I think TypeScript error might be misleading,
because the object is not "possibly null", but in my example it is definitely null. This might be a little bit
nitpicky, but that might still lead you towards a wrong path. While this point might be controversial, Flow is
definitely better at giving more context. It does not only show where the error would happen (the `toString` method
call); in addition it also show what assignment is responsible for that error (`let value = null;`). Again, this might
be not that important in such a small example, but will definitely help with bigger code pieces.

This is also true for functions built directly into the browser. Let's have a look at how TypeScript handles the
`document.write` method using the following example:

```javascript
document.write(30, 10);
```

TypeScript shows the following error:

![Argument of type '30' is not assignable to parameter of type 'string'.](/images/posts/typescript-document-write.webp)

I was preparing this simple example for a course I was giving at the time, and it might sound stupid, but I really
tripped over this error message. I was not aware that the `document.write` was typed to only accept strings in
TypeScript, which I think is a little bit confusing, because numbers are also outputted just the way you would expect
it. To be fair, **Flow has typed this function exactly the same way, but just because it gives more context in the
error message it is easier to spot the error:**

![Cannot call document.write because number is incompatible with string in array element.](/images/posts/flow-document-write.webp)

In its error message Flow shows that the `document.write` method has been defined to be called with strings only, which
makes the error a lot more obvious. **And this advantage gets even more important, if the codebase you are working on
is bigger than a few lines of code.**

## Using 3rd party types

Apart from the **strictness of the type system** (I want to make sure that my code is free of errors) and the **quality
of the error message** (if there are errors in the code I would like to find them as fast as possible), I think it is
very important to see how **3rd party types are integrated in a type system**. That is necessary if you install a
package from NPM. Without any type information the type checker can't really tell if you call the package's functions
correctly.

Both Flow and TypeScript have mechanisms to add library definition files, but I don't want to dig too deep into this,
because what is important to me, is that I don't have to write these library definitions for every package I use
manually. Adding types to your library that can be used in projects depending on these libraries is not a big problem
in both type checkers, but it is very unrealistic to think that this will happen for every library. So for most NPM
packages types have to be provided in a different way. And this is where TypeScript excels compared to Flow.

For Flow there is the [`flow-typed` project](https://github.com/flow-typed/flow-typed), which is a central repository
for Flow library definitions. And I think the word "central" is the problematic one here. You are somehow dependant on
a few persons to maintain this repository (you can create PRs, but people have to find time to agree with you and merge
that stuff), and the integration into your project is a little bit weird, to say it in a nice way. `flow-typed` has a
CLI tool, which copies the type definitions from their central repository into a `flow-typed` folder in your project,
which you have to commit to your version control system.

This feels very cumbersome, especially since there would already be a central repository called NPM. I never really got
why the types were not created as simple NPM packages, which could then be installed and used, without having to commit
anything to my own repository. And **installing 3rd party types as separate packages is exactly what TypeScript is
doing**. This is also the reason I think TypeScript is a lot better in that regard.

## Conclusion

I am still not very sure, which of both type systems I should prefer. TypeScript has made a lot of improvements,
especially regarding the majority of reasons we decided against TypeScript a few years ago. However, **Flow seems still
to be more strict and has better error messages, two very important aspect of a type system**. On the other handside
**TypeScript is more popular, has a bigger community, and handles 3rd party types a lot better**. Flow's advantage of
being more strict is somehow lost, when using a lot of 3rd party packages. That is because if no Flow types exists,
Flow considers the entire 3rd party code untyped.

Until recently I would have said TypeScript is the clear winner, but then I saw that
**[Flow is still being worked on](https://github.com/facebook/flow/commits/master)**. But they continue to introduce
breaking changes quite often, which makes updating it a tedious job (although most of the changes make sense from my
point of view). TypeScript is still the more active project, and has better integrations in all kind of other tooling.
For these reasons I would say it is much more likely that Flow reaches its end of life than TypeScript.

So in conclusion, my current recommendation would be:

- **Don't switch your project from Flow to TypeScript just for the sake of it.** Flow has some advantages too, and
  unless there is a very specific reason for this undertaking, it is probably not worth it.
- **For new projects I would go with TypeScript.** Despite its disadvantages, it is much more likely to survive than
  Flow.
