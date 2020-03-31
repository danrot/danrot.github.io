---
layout: post
title: Testing traits with non-public methods
description: Testing a trait with PHPUnit is not that easy, especially if it only contains private methods. See how it can be achieved in this step by step introduction.

tags:
    - programming
    - php
    - testing
    - traits
---
In one of our last [Sulu](http://www.sulu.io) Pull Request we made use the quite new PHP feature [traits](http://www.php.net/manual/en/language.oop5.traits.php). We used it for two small functions, which should help us to read some values from a symfony request object. The trait looks like the following:

```php
trait RequestParametersTrait
{
    protected function getRequestParameter(
        Request $request, 
        $name, 
        $force = false, 
        $default = null
    )
    {
        $value = $request->get($name, $default);
        if ($force && $value === null) {
            throw new MissingParameterException(
                get_class($this),
                $name
            );
        }
        return $value;
    }

    protected function getBooleanRequestParameter(
        Request $request, 
        $name, 
        $force = false, 
        $default = null
    )
    {
        $value = $this->getRequestParameter(
            $request, 
            $name, 
            $force, 
            $default
        );
        if ($value === 'true') {
            $value = true;
        } elseif ($value === 'false') {
            $value = false;
        } elseif ($force && $value !== true && $value !== false) {
            throw new ParameterDataTypeException(
                get_class($this),
                $name
            );
        }

        return $value;
    }
} 
```

As it turned out, it was not that easy to test this kind of code, because the two methods in the trait are protected. But I will go through this step by step.

The first thing that I have found out, is that traits cannot be handled by PHPUnit before version 3.8, but starting with this version there are two possibilities to handle traits: First there is the [getMockForTrait-method](http://phpunit.de/manual/current/en/test-doubles.html#test-doubles.mocking-traits-and-abstract-classes), which creates a mock for the given trait. But I used the undocumented getObjectForTrait-method, which just returns an object using the given trait. So I came up with the following setup:

```php
class RequestParametersTraitTest extends \PHPUnit_Framework_TestCase
{
    /**
     * @var RequestParametersTrait
     */
    private $requestParametersTrait;

    public function setUp()
    {
        $this->requestParametersTrait = $this->getObjectForTrait(
            'Sulu\Component\Rest\RequestParametersTrait'
        );
    }
}
```

The next problem was that the methods of the trait have been protected, and therefore could not be used in the test directly. I already knew that it is easily possible to [test your privates](http://sebastian-bergmann.de/archives/881-Testing-Your-Privates.html) on a usual class, but the ReflectionMethod-Class didn't seem to work correctly with traits when used like in the following lines:

```php
$getRequestParameterReflection = new ReflectionMethod(
    'Sulu\Component\Rest\RequestParametersTrait',
    'getRequestParameter'
);
$getRequestParameterReflection->setAccessible(true);
$getRequestParameterReflection->invoke(
    $this->requestParametersTrait,
    [...]
);
```

It just kept throwing an exception saying that the given object is not of the defined class. So I tried to solve this issue, and after some time I came up with a working solution. It was as easy as using the return value of the get_class-method instead of the hardcoded string:

```php
$getRequestParameterReflection = new ReflectionMethod(
    get_class($this->requestParametersTrait),
    'getRequestParameter'
);
$getRequestParameterReflection->setAccessible(true);
$getRequestParameterReflection->invoke(
    $this->requestParametersTrait,
    [...]
);
```

This works because PHPUnit really creates a new object with its own class, on which the ReflectionMethod seems to work again. For a better understanding you can have a look at the [working example](https://github.com/sulu-cmf/sulu/blob/12926af5fed6ce14e5c56cff5230d9cb1cd5472c/tests/Sulu/Component/Rest/RequestParametersTraitTest.php).
