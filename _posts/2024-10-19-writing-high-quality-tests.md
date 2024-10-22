---
layout: post
title: Writing high quality tests
excerpt: Tests often do not get the attention they deserver especially during code reviews, even though there are some
    things a reviewer could look out for.

tags:
    - testing
    - php
    - javascript
    - react
---

Unfortunately, tests still do not get the attention they would deserve in many organizations. Sometimes it feels like
developers feel guilty if they are no writing any tests, but at the same time test code is often not properly reviewed.
Instead, the only thing that is often checked in a review is if there are tests, which is a shame, because just having
tests is not good enough. Actually, they should be of at least the same quality as all other code in a project, if not
even of higher quality. Otherwise testing might indeed hold you back, since tests fail far too often, are hard to
understand, or take way too long to run. I have already discussed some of these points in [my blog post about using
in-memory implementations instead of repository
mocks](/2023/09/22/avoid-mocking-repositories-by-using-in-memory-implementations.html). Now I want to discuss some
other, more general, things I look out for when writing tests.

## Minimalism is your friend

[Stack Overflow asks you to add minimal, reproducible examples to
questions](https://stackoverflow.com/help/minimal-reproducible-example), and in my opinion this is also very good advice
for writing tests for the exact same reasons. Especially when reading a test months after you have written it, it is
much easier to fully understand what is happening if less stuff is happening. So **only write the code that is
absolutely necessary for the test**, and resist the temptation to add more stuff just because it is easy to do so. But
the test code must of course still be complete, i.e. a test should contain as many lines as necessary, but as few as
possible.

## Go for the 100% code coverage

That might be an unpopular opinion, but I think it totally makes sense to aim for a 100% code coverage, even though many
seem to consider this a bad practice.

Sometimes teams settle for a lower value, e.g. a code coverage of 90%. However, that does not make a lot of sense to me.
First of all, all these numbers are somewhat arbitrary and hard to back up using data. Also, when writing new code, not
all of it needs to be tested in order to pass that threshold. And if somebody managed to get the coverage up the next
person could get away with writing no tests at all while still keeping a code coverage higher than 90%, which results in
a wrong feeling of confidence.

One of the excuses I often hear is that it does not make sense to write tests for simple getters and setters. And maybe
surprisingly, I totally agree with that. But here is the catch: **If none of the tests actually use these getters and
setters, then there is probably no need to have them.** So instead of complaining about how hard it is to achieve 100%
test coverage, it would most likely be better to not write code that is not required in the first place. This also
avoids the maintenance burden every line of code brings with it.

However, there is a small catch: Sometimes code does weird things, which might cause code coverage tools to mark some
lines as uncovered, even though it was executed during the test run. I did not run into situations like this a lot, but
if there is no way to make this work I exclude them from code coverage. E.g. PHPUnit allows to do that using their
[`codeCoverageIgnore` annotation](https://docs.phpunit.de/en/10.5/code-coverage.html#ignoring-code-blocks):

```php
class SomeClass
{
    /**
     * @codeCoverageIgnore
     */
    public function doSomethingNotDetectedAsCovered()
    {

    }
}
```

This way this function is not included in the code coverage analysis, **which means it is still possible to reach a code
coverage of 100%**, and I also keep checking for that value. The alternative is to settle for a lower value than 100%,
but then there are the same issues mentioned above: Other code might also not be covered by tests, and that might be
missed.

With that being said, a 100% code coverage certainly does not give any guarantees that your code does not have any bugs.
But if you do have uncovered lines in your application code it is a guarantee that your tests will not spot potential
errors in that line.

## Write good assertions

The reason tests are being written is that we want to assert a certain behavior of the code. Therefore assertions are a
very essential part of testing.

Of course the most important consideration when writing assertions is that it correctly tests the code's behavior. But a
very close second is how the assertion behaves when the code is failing. If an assertions fails for whatever reason, the
problem should be as obvious to the developer as possible. A situation in which this is apparent is the situation that
is currently being worked on in [this Symfony pull request](https://github.com/symfony/symfony/pull/58456). Symfony
comes with a `assertResponseStatusCodeSame` method, which allows to check for the status code of a response in a
functional test:

```php
<?php

declare(strict_types=1);

class LoginControllerTest extends WebTestCase
{
    public function testFormAttributes(): void
    {
        $client = static::createClient();

        $client->request('GET', '/login');
        $this->assertResponseStatusCodeSame(200);

        $this->assertSelectorCount(1, 'input[name="email"][required]');
    }
}
```

The problem with this test is the output it generates in case the status code is not `200`. Since tests usually run in a
development environment, Symfony will return an error page when this URL is accessed, and the
`assertResponseStatusCodeSame` method will output the entire response in case the assertion fails. This output is
incredibly long, since this does not only return HTML, but also CSS and JavaScript, and my scrollback buffer is
literally too small to display the entire message.

This is absolutely the worst example I have encountered so far, but it can also be annoying if the wrong assertions are
used in the code. Let us have a look at the output of the `assertSelectorCount` assertion above, which fails with the
following message if the given selector does not yield exactly one element:

```plaintext
Failed asserting that the Crawler selector "input[name="email"][required]" was expected to be found 1 time(s) but was found 0 time(s).
```

It gives a pretty good idea about the occuring problem. However, the assertion could also be written in a different way
(do not do this at home!):

```php
$this->assertTrue($client->getCrawler()->filter('input[name="email"][required]')->count() === 1);
```

Somebody might argue that this does exactly the same, therefore it does not matter which variant is used. This could not
be further from the truth, since the following message appears if there is not a single required `input` field for an
email:

```plaintext
Failed asserting that false is true.
```

This does not help at all, and whoever works on fixing the problem first of all has to figure out what the problem
actually is. What this shows, is that always a fitting assertion should be used, and [PHPUnit comes with many
assertions](https://docs.phpunit.de/en/11.4/assertions.html) fitting all kind of use cases. Sometimes it even makes
sense to create a custom assertion.

A relatively new assertion I have seen gaining popularity in recent years is [snapshot
testing](https://jestjs.io/docs/snapshot-testing). Especially when starting to work on a front end project it seems to
help a lot. I've often used it with React in the past. The main gist is that your tests look something like this:

```javascript
import renderer from 'react-test-renderer';
import Component from '../Component';

it('renders correctly', () => {
    const tree = renderer
        .create(<Component />)
        .toJSON()
    ;

    expect(tree).toMatchSnapshot();
});
```

The magic happens in the `toMatchSnapshot` method. In the very first run it write the content of the `tree` variable
into a separate file. On subsequent runs it compares the new value of the `tree` value with what it has previously
stored in its separate file. If something changed it will fail the test and show a diff, with an option to update the
snapshot again, which means you can fix your tests in a blink of an eye.

While this sounds really nice, it also comes with some downsides. First, snapshots are quite brittle, because whenever
the rendered markup of the `Component` changes the tests will fail. Second, the intent of the test is hidden, since it
does not explain what the author actually wanted to test.

However, what I really enjoyed about it, was that whenever I changed a component, it reminded me of all other components
using that component, because all those snapshots failed on the first run. For this reason I liked having at least one
snapshot test per component.

## Conclusion

So to sum up, I think there are a few things you could start doing right away in order to improve the quality of your
tests:

- Keep the code in a test to the absolutely required minimum
- Aim for a code coverage of a 100% and properly exclude code from the code coverage mechanism if it cannot be tested
- Use the correct assertions to get better error messages when your tests are failing

In my opinion following these few rules will already make a huge difference and help you enjoying working in the code
base for a long time!
