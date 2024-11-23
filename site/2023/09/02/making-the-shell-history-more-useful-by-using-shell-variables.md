---
layout:
    post: true
title: Making the shell history more useful by using shell variables
excerpt: The shell history is cluttered with useless commands if stuff like tokens are included. Shell variables allow to exclude such content from the history.

tags:
    - cli
    - linux
    - fish
---

I already described [that I like using curl for testing HTTP
APIs](/2023/07/19/combine-jq-with-curl-to-improve-its-json-handling.html). I have also used that approach a lot lately,
but with an API that required some kind of [HTTP
authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication). This is also no problem for
[curl](https://curl.se/), which can send the necessary `Authorization` header using its `-H` flag:

```bash
curl -X GET -H "Authorization: Bearer some-lengthy-but-not-infinitely-valid-token" localhost/some-uuid-that-might-be-valid-only-once
```

While this basically works, it is still problematic from a shell history perspective. I already hinted at the problems
in the placeholder values in the above `curl` command. **Re-executing this command only works easily as long as the
passed values in headers and URL are valid.** In case the token or the passed value changes frequently it becomes very
tedious to reuse the command from history, since after pressing up until the desired command appears you must fiddle
around (moving the cursor, deleting some characters, inserting new ones, ...) to replace values which became invalid
with valid ones. In my case this mostly was about the bearer token, which I had to retrieve again after it became
invalid, giving me a hard time reusing existing commands.

However, I just realized recently that there is quite an easy fix for that. **By placing those changing values in shell
variables the command in the history is much easier to reuse.** So instead of copying tokens, UUIDs, etc. directly into
the command I set them as shell variables and use these shell variables in the command. The following examples work with
the [fish shell](https://fishshell.com/):

```bash
set TOKEN some-lengthy-but-not-infinitely-valid-token
set UUID some-uuid-that-might-be-valid-only-once

curl -X GET -H "Authorization: Bearer $TOKEN" localhost/$UUID
```

This might look like more work for the first command (who am I  kidding, it also is more work for the first command),
but the huge advantage is that the last command can be easily reused. **Instead of pressing up and manually moving the
cursor and replacing parameters you can set new values to the shell variables and execute the command from history as
is.** So the workflow after retrieving a new token and UUID is as follows:

```bash
set TOKEN another-lengthy-but-not-infinitely-valid-token
set UUID another-uuid-that-might-be-valid-only-once

# Press up to get the curl command in history and execute it right away
```

This might not look like a big deal now, but especially if the command to execute is more complex this gets really
useful. To give an even better example, I recently worked on an HTTP API using authentication, which had a use case
involving a two-step process, i.e. receiving a token from the API that has to be sent in another request. For testing I
executed two `curl` commands at once by using command substitution, whereby both are using the same shell variables for
the token and the inner one [uses `jq` as described in my previous blog
post](/2023/07/19/combine-jq-with-curl-to-improve-its-json-handling.html) to only retrieve the value I need for the
second `curl` command (the used `-r` flag for `jq` returns the raw value, not a beautified one, which would probably
make problems when used with other commands). In fish [command substitution uses parentheses instead of backticks as in
e.g. bash](https://fishshell.com/docs/current/tutorial.html#command-substitutions), but the idea is pretty much the same
in any shell. This is how such a command can look like:

```bash
set TOKEN some-lengthy-but-not-infinitely-valid-token

curl -X GET -H "Authorization: Bearer $TOKEN" localhost/item/(curl -X POST -H "Authorization: Bearer $TOKEN" localhost/item | jq -r .id)
```

In this case, using the environment variable makes even more sense since the token has to be used twice in the same
command, which would make replacing it even more cumbersome.

This small change in writing shell commands can make a huge difference when re-executing commands multiple times, for
which reason I wanted to share it with you!
