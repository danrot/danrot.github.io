---
layout:
    post: true
title: Avoid mocking repositories by using in-memory implementations
excerpt: Mocking libraries come with disadvantages, but fortunately they can be replaced by in-memory implementations, at least for repositories.
last_modified_at: 2023-09-25

tags:
    - testing
    - php
    - symfony
---

One of the most important aspects of testing - besides finding errors in an application - is how long it takes to run
them. If tests for an application take minutes or even hours to finish, then they are not suitable for developing using
a fast feedback loop and developers might not run them as often as they should.

The [testing pyramid](https://martinfowler.com/bliki/TestPyramid.html) has many goals, and one of them is to have a fast
test suite so that developers do not have to wait too long for their tests to finish. It does so by introducing three
different kinds of tests: UI, service, and unit. **The basic idea is that unit tests are the fastest to run, and
therefore most of the testing should be implemented as unit tests.**

Testing does not come with clear definitions for all of its terms, so I want to clarify that lately, I like to use
[sociable unit tests over solitary ones](https://www.martinfowler.com/bliki/UnitTest.html). They make me much more
confident since a real implementation is used for the dependencies of a unit. However, **if not used carefully they
might be very slow**.

Solitary unit tests will always mock dependencies, which makes them fast **since all dependencies of a unit are
replaced with a mock implementation**. Very often some kind of library or framework is used for that, e.g. [test doubles
from PHPUnit](https://docs.phpunit.de/en/9.6/test-doubles.html) or a separate mocking library like
[Prophecy](https://github.com/phpspec/prophecy) or [Mockery](https://github.com/mockery/mockery). While they can make
tests fast by setting up expectations and the desired return value, especially if used for slow parts like code
connecting to a database, they come with some serious issues:

- Mocks can easily hide actual errors because they are still returning "old" values if the behavior of an
implementation changes for some reason.
- Mocks are often defined in multiple tests in a similar way, making them awkward to use compared to a "real"
implementation.
- Mocks are tightly coupled to the real implementation making refactorings even harder since a change might cause
necessary changes in many tests as well.
- Mocks are not very straightforward to define and make the test code harder to read, although that might be subjective.
- Mocking libraries often use dynamic classes, which makes understanding and debugging them quite hard. When stepping
into a mocked function call in a debug session there is no straightforward code. Instead, you might land in a [file with
hundreds of lines of non-trivial
code](https://github.com/phpspec/prophecy/blob/098f8850e4bd800b7734c65b2c8c10b28d87f10e/src/Prophecy/Prophecy/MethodProphecy.php),
or - even worse - in a dynamically created file not even existing in the file system.

At the beginning of my career, I was not aware of these issues and used solitary unit tests with loads of mocks. We
often did refactorings, which did not make tests fail although the code was not working in production and I have spent
quite some hours debugging third-party code.

Fortunately, there is another method of making tests fast and have more reliable tests at the same time: **Define a
single interface, write an abstract test against that interface, and have the same tests run against one implementation
for production and a much faster implementation for tests.** This will solve multiple of the issues above:

- Errors are less likely to be hidden because both implementations should behave the same since they run against the
same tests.
- The test implementation can be reused in every test instead of setting up mocks every time.
- The tests are using a simple class instead of a complex mocking library.
- Debuggers will land in a real class developers know, instead of something dynamically generated.

The rest of the blog post will explain how this can be done in Symfony, but the general principles should apply to any
framework and programming language. **The example code can also be found as a working application in a [GitHub
repository](https://github.com/danrot/memory-repository-testing).**

## Define a common interface

The example will implement two different repositories, one using the [Doctrine
ORM](https://www.doctrine-project.org/projects/orm.html) for use in production and an in-memory implementation using an
array to store objects. I will use a generic `Item` class to keep things generic:

```php
<?php

namespace App\Domain;

use Doctrine\ORM\Mapping\Column;
use Doctrine\ORM\Mapping\Entity;
use Doctrine\ORM\Mapping\Id;
use Symfony\Component\Uid\Uuid;

#[Entity]
class Item
{
    #[Id]
    #[Column(type: 'uuid')]
    private Uuid $id;

    public function __construct(
        #[Column] private string $title,
        #[Column] private string $description,
    ) {
        $this->id = Uuid::v4();
    }

    public function getId(): Uuid
    {
        return $this->id;
    }

    public function getTitle(): string
    {
        return $this->title;
    }

    public function getDescription(): string
    {
        return $this->description;
    }
}

```

*Good domain objects would contain more methods than just getters, but for the sake of brevity, I will keep it like that
for this blog post.*

This is more or less the simplest Doctrine entity that can be created, it only contains a `Uuid` as an identifier and a
field for a title and a description. Additionally, the domain layer introduces an interface for an `ItemRepository`,
which takes care of persisting and retrieving objects from data storage:

```php
<?php

namespace App\Domain;

interface ItemRepositoryInterface
{
    public function add(Item $item): void;

    /**
     * @return Item[]
     */
    public function loadAll(): array;

    /**
     * @return Item[]
     */
    public function loadFilteredByTitle(string $titleFilter): array;
}

```

**The contract defined in this interface allows the application to not care about which kind of storage is used, and
therefore most tests can use a much faster one than a relational database.** However, in order to swap out
implementations reliably it must be ensured that all of them behave in the same way. That is where the abstract test
case comes in.

## Implement the abstract test case

As mentioned previously, the abstract test class is responsible for ensuring that all implementations of the
`ItemRepositoryInterface` behave in the same way. One characteristic of repositories is that adding the same object
twice will result in having the object only once in the repository. So let's test that and adding two different objects
to the repository as well as filtering items by their title. Since currently the `ItemRepository` interface only has
three methods this covers all of its functionality already.

```php
<?php

namespace App\Tests\Repository;

use App\Domain\Item;
use App\Domain\ItemRepositoryInterface;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

abstract class AbstractItemRepositoryTest extends KernelTestCase
{
    abstract protected function createItemRepository(): ItemRepositoryInterface;

    abstract protected function flush(): void;

    public function testMultipleAddOfItem(): void
    {
        $itemRepository = $this->createItemRepository();

        $item = new Item('Test title', 'Test description');

        $itemRepository->add($item);
        $itemRepository->add($item);

        $this->flush();

        $items = $itemRepository->loadAll();

        $this->assertCount(1, $items);
        $this->assertContains($item, $items);
    }

    public function testLoadAllWithMultipleItems(): void
    {
        $itemRepository = $this->createItemRepository();

        $item1 = new Item('Test title 1', 'Test description 1');
        $item2 = new Item('Test title 2', 'Test description 2');

        $itemRepository->add($item1);
        $itemRepository->add($item2);

        $this->flush();

        $items = $itemRepository->loadAll();

        $this->assertCount(2, $items);
        $this->assertContains($item1, $items);
        $this->assertContains($item2, $items);
    }

    public function testLoadFilteredByTitle(): void
    {
        $itemRepository = $this->createItemRepository();

        $item1 = new Item('Test title 1', 'Test description 1');
        $item2 = new Item('Title 2', 'Description 2');
        $item3 = new Item('Test title 3', 'Test description 2');

        $itemRepository->add($item1);
        $itemRepository->add($item2);
        $itemRepository->add($item3);

        $this->flush();

        $items = $itemRepository->loadFilteredByTitle('Test title');

        $this->assertCount(2, $items);
        $this->assertContains($item1, $items);
        $this->assertContains($item3, $items);
    }
}
```

The test class needs to extend from the `KernelTestCase` of Symfony to allow getting a reference to the
`EntityManagerInterface` of Doctrine, which enables testing against the real database for the Doctrine repository later.

Also, two abstract methods need to be overridden by the tests for the concrete applications:

- `createItemRepository` is a template method allowing to swap out the implementation for the tests.
- `flush` is used to actually send changes to the database, which is necessary for the Doctrine repository later, unless
you want to add the `flush` call to the repository itself (which I would not recommend, since a single request should
have all of its changes or none being committed to the database).

With that abstract test case in place, the concrete implementations can be implemented and tested against the same set
of tests.

## Write the production and testing implementation

The concrete implementations of these tests will override the `createMatchRequest` and `flush` methods. Therefore the
test for the Doctrine implementation looks like this:

```php
<?php

namespace App\Tests\Repository\Doctrine;

use App\Domain\ItemRepositoryInterface;
use App\Repository\Doctrine\ItemRepository;
use App\Tests\Repository\AbstractItemRepositoryTest;
use Doctrine\ORM\EntityManagerInterface;

class ItemRepositoryTest extends AbstractItemRepositoryTest
{
    protected function createItemRepository(): ItemRepositoryInterface
    {
        return new ItemRepository($this->getContainer()->get(EntityManagerInterface::class));
    }

    protected function flush(): void
    {
        $this->getContainer()->get(EntityManagerInterface::class)->flush();
    }

    protected function setUp(): void
    {
        $this->getContainer()->get(EntityManagerInterface::class)->getConnection()->setNestTransactionsWithSavepoints(true);
        $this->getContainer()->get(EntityManagerInterface::class)->getConnection()->beginTransaction();
    }

    protected function tearDown(): void
    {
        $this->getContainer()->get(EntityManagerInterface::class)->getConnection()->rollBack();
    }
}
```

In here the `createItemRepository` will return an instance of `App\Repository\Doctrine\ItemRepository`, which also
requires an instance of the `EntityManagerInterface` to work properly since it uses this class to store and retrieve
data from the database. The `flush` method will call `flush` on the `EntityManagerInterface`, which results in the data
actually being stored (this is called in the abstract test case). Additionally, the `setUp` and `tearDown` methods will
ensure that each test is enclosed in a transaction by calling `beginTransaction` and `rollBack`. **This way no data is
actually stored in the database, which makes the tests very fast**. However, be careful, since there might still be
database checks that could fail at this point. Last but not least the `setNestTransactionWithSavepoints` method is
necessary to allow nesting transactions.

The following `ItemRepository` implementation will make use of the `EntityManagerInterface` and fulfill the previously
shown tests:

```php
<?php

namespace App\Repository\Doctrine;

use App\Domain\Item;
use App\Domain\ItemRepositoryInterface;
use Doctrine\ORM\EntityManagerInterface;

class ItemRepository implements ItemRepositoryInterface
{
    public function __construct(private EntityManagerInterface $entityManager)
    {

    }

    public function add(Item $item): void
    {
        $this->entityManager->persist($item);
    }

    public function loadAll(): array
    {
        /** @var Item[] */
        return $this->entityManager
            ->createQueryBuilder()
            ->from(Item::class, 'i')
            ->select('i')
            ->getQuery()
            ->getResult()
        ;
    }

    public function loadFilteredByTitle(string $titleFilter): array
    {
        /** @var Item[] */
        return $this->entityManager
            ->createQueryBuilder()
            ->from(Item::class, 'i')
            ->select('i')
            ->where('i.title LIKE :titleFilter')
            ->setParameter('titleFilter', $titleFilter . '%')
            ->getQuery()
            ->getResult()
        ;
    }
}
```

The tests for the memory implementation are a bit simpler since there is no dependency like the `EntityManagerInterface`
and there is also no need to call a method like `flush`. Therefore `createItemRepository` will just return a new
instance and the `flush` method can be left empty:

```php
<?php

namespace App\Tests\Repository\Memory;

use App\Domain\ItemRepositoryInterface;
use App\Repository\Memory\ItemRepository;
use App\Tests\Repository\AbstractItemRepositoryTest;

class ItemRepositoryTest extends AbstractItemRepositoryTest
{
    protected function createItemRepository(): ItemRepositoryInterface
    {
        return new ItemRepository();
    }

    protected function flush(): void
    {

    }
}
```

The implementation fulfilling these tests uses a simple array containing the objects, which only needs to check if the
array already contains the passed `Item` to avoid inserting it multiple times:

```php
<?php

namespace App\Repository\Memory;

use App\Domain\Item;
use App\Domain\ItemRepositoryInterface;

class ItemRepository implements ItemRepositoryInterface
{
    /**
     * @var Item[]
     */
    private array $items = [];

    public function add(Item $item): void
    {
        if (in_array($item, $this->items)) {
            return;
        }

        $this->items[] = $item;
    }

    public function loadAll(): array
    {
        return $this->items;
    }

    public function loadFilteredByTitle(string $titleFilter): array
    {
        return array_values(
            array_filter(
                $this->items,
                fn (Item $item) => str_contains($item->getTitle(), $titleFilter),
            ),
        );
    }
}
```

**The only bit that is a bit cumbersome here is the `loadFilteredByTitle` method, since this method will only be
implemented for the tests, which would not be necessary if mocks were used.** But therefore mocks might lead to wrong
test results if the behavior of this method changes for some reason. In this example `array_filter` was used to return
only the items matching the given criteria, but it would also be possible to use a `foreach` loop or whatever else works
for you. Of course this is still a very simple example and depending on the actual logic this might be harder to
implement, but I would not consider this wasted effort since it gives me confidence and fast tests.

**This implementation cannot be used in a production environment unless you want every request to start with no data at
all.** However, other than that, this implementation behaves exactly the same as Doctrine one actually storing data in
the database. **This makes it a great candidate to use for other tests, many of which mocks would probably be used
otherwise.**

## Use the correct implementation in each environment

So now that we have two implementations of the same interface we can use them interchangeably in e.g. a REST Controller
like shown in the following code:

```php
<?php

namespace App\Controller;

use App\Domain\Item;
use App\Domain\ItemRepositoryInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class ItemController extends AbstractController
{
    #[Route('/items', methods: ['GET'])]
    public function list(Request $request, ItemRepositoryInterface $itemRepository): JsonResponse
    {
        $titleFilter = $request->query->getString('titleFilter');
        $items = $titleFilter ? $itemRepository->loadFilteredByTitle($titleFilter) : $itemRepository->loadAll();

        return $this->json($items);
    }

    #[Route('/items', methods: ['POST'])]
    public function create(Request $request, ItemRepositoryInterface $itemRepository): JsonResponse
    {
        /** @var \stdClass */
        $data = json_decode($request->getContent());
        $item = new Item($data->title, $data->description);

        $itemRepository->add($item);

        return $this->json($item);
    }
}
```

This is a pretty standard Symfony controller using the `ItemRepositoryInterface` to inject one of the above
implementations. Symfony comes with [autowiring](https://symfony.com/doc/current/service_container/autowiring.html)
these days so that usually it is not necessary to configure anything. However, since we have two implementations of the
`ItemRepositoryInterface` Symfony cannot know which one to use. Therefore we have to add the following line to the
`config/services.yaml` file:

```yaml
services:
    # other stuff...
    App\Domain\ItemRepositoryInterface: '@App\Repository\Doctrine\ItemRepository'
```

This way Symfony knows that it should inject the Doctrine `ItemRepository` whenever the `ItemRepositoryInterface` is
used.

Mind that the controller does not call the `EntityManagerInterface::flush` method. I like to avoid using such methods in
the controller, since depending on which `ItemRepositoryInterface` is being used it might not be necessary. However, in
the case of the Doctrine implementation this must be done, therefore I started to implement a listener for that:

```php
<?php

namespace App\Repository\Doctrine;

use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\KernelEvents;

class FlushEventSubscriber implements EventSubscriberInterface
{
    public function __construct(private EntityManagerInterface $entityManager)
    {

    }

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::RESPONSE => ['flush'],
        ];
    }

    public function flush(): void
    {
        $this->entityManager->flush();
    }
}
```

**I haven't tested it, but my guess is, that the `flush` method should not take a long time in case no entity has been
changed.** An alternative approach would be to introduce another `FlushInterface` or something similar, that can also be
exchanged based on the used repository implementation.

The test for this controller can now be implemented something like this:

```php
<?php

namespace App\Tests\Controller;

use App\Domain\Item;
use App\Domain\ItemRepositoryInterface;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class ItemControllerTest extends WebTestCase
{
    public function testList(): void
    {
        $client = static::createClient();

        /** @var ItemRepositoryInterface */
        $itemRepository = $client->getContainer()->get(ItemRepositoryInterface::class);

        $itemRepository->add(new Item('Title 1', 'Description 1'));
        $itemRepository->add(new Item('Title 2', 'Description 2'));

        $client->request('GET', '/items');

        $responseContent = $client->getResponse()->getContent();
        $this->assertNotFalse($responseContent);
        $responseData = json_decode($responseContent);

        $this->assertIsArray($responseData);
        $this->assertCount(2, $responseData);
        $this->assertEquals('Title 1', $responseData[0]->title);
        $this->assertEquals('Description 1', $responseData[0]->description);
        $this->assertEquals('Title 2', $responseData[1]->title);
        $this->assertEquals('Description 2', $responseData[1]->description);
    }

    public function testListWithTitleFilter(): void
    {
        $client = static::createClient();

        /** @var ItemRepositoryInterface */
        $itemRepository = $client->getContainer()->get(ItemRepositoryInterface::class);

        $itemRepository->add(new Item('Test title 1', 'Description 1'));
        $itemRepository->add(new Item('Title 2', 'Description 2'));
        $itemRepository->add(new Item('Test title 3', 'Description 3'));

        $client->request('GET', '/items?titleFilter=Test title');

        $responseContent = $client->getResponse()->getContent();
        $this->assertNotFalse($responseContent);
        $responseData = json_decode($responseContent);

        $this->assertIsArray($responseData);
        $this->assertCount(2, $responseData);
        $this->assertEquals('Test title 1', $responseData[0]->title);
        $this->assertEquals('Description 1', $responseData[0]->description);
        $this->assertEquals('Test title 3', $responseData[1]->title);
        $this->assertEquals('Description 3', $responseData[1]->description);
    }

    public function testCreate(): void
    {
        $client = static::createClient();

        /** @var ItemRepositoryInterface */
        $itemRepository = $client->getContainer()->get(ItemRepositoryInterface::class);

        $client->jsonRequest('POST', '/items', ['title' => 'Title', 'description' => 'Description']);

        $items = $itemRepository->loadAll();
        $this->assertCount(1, $items);
        $this->assertEquals('Title', $items[0]->getTitle());
        $this->assertEquals('Description', $items[0]->getDescription());
    }
}
```

I will not go into every detail of testing in Symfony (the [Symfony testing
documentation](https://symfony.com/doc/current/testing.html) already does a decent job at this), instead, I will only
talk about the highlight: **This test relies on the `ItemRepositoryInterface` instead of the Doctrine one.** It is used
to setup some data in the `testList` and `testListWithTitleFilter` tests and also to assert if data was actually stored
`testCreate`. If the tests are run like this they will not often succeed, since the database is never reset. However,
the goal of this blog post is not to use databases for this kind of test anyway. Therefore a `config/services_test.yaml`
file is created instead, which contains the following lines:

```yaml
services:
    App\Domain\ItemRepositoryInterface: '@App\Repository\Memory\ItemRepository'
```

This way for all tests the `ItemRepository` using just an array as memory is used whenever the
`ItemRepositoryInterface` is being referred. This means that with this configuration no database at all is used in the
above test for the controller, which makes the tests incredibly fast. **At the same time, these tests are quite
reliable since the memory implementation behaves like the Doctrine implementation because of the
`AbstractItemRepositoryTest`.**

The only test actually running against the database is the `ItemRepositoryTest` for the Doctrine implementation, which
only injects the `EntityManagerInterface`, for which reason the configuration in `services_test.yaml` does not apply in
this case.

## Conclusion

**In summary, I can say that I have never been so happy with my tests.** They are incredibly fast, give me a lot of
confidence since the memory implementation should behave very similar to the Doctrine implementation, and there is no
need to redefine a lot of expectations in many tests as would be the case with mocks.

**The only downside I can think of is that in the case of repositories complex queries might be hard to implement using
just an array, but in my opinion, this is not a real deal breaker.** And quite often some calls to array methods like
`array_filter` already go a long way in this regard.

I encourage you to try this kind of testing in a project and I am sure that you will not regret it!
