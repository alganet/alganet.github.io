<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-02-11-02-Validando-Estrutura-Markdown-em-uma-Unica-Expressao-Declarativa.pt
date: February 11, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# Validating Markdown Structure in a Single Declarative Expression

Back in 2010, I started this little project called [Respect\Validation](http://github.com/Respect/Validation).

At first glance, it's a cute little library that uses fluent interfaces to validate simple values:

```
// Validates that $something is an integer between 1 and 10

v::intVal()->positive()->between(1, 10)->assert($something);

```

However, that's **just the tip of the iceberg** of what this library can actually do.

Over the years, I've used it to not only validate things but build entire declarative rule systems, and I quite never shared that aspect of it. Until now!

## Crafting an Insane Example

Let's validate, in a single declarative expression, an entire Markdown file.
- **Header Structure**: Let's check if some file has some expected headers, in the correct order and level.
- **Code Blocks**: Let's ensure the code blocks are valid PHP code that runs with no error and output something. Let's also validate each output of the code runs.


I believe that example can give some perspective on the power and flexibility of declarative validation.

So, how does it look like? The general structure is something like this:

```
try {
    // Here is the expression we will build
    $validator = v::something()->somethingElse()->somethingMore();
    // Here we call it to validate the file
    $validator->assert('example.md');
} catch (ValidationException $e) {
    // Print a message with all the errors found in the file
    echo $e->getFullMessage() . "
";
}

```

Nice. And what kind of messages can we expect? I want to build something like this:

```
- Markdown structure must pass all the rules
  - Heading structure must pass all the rules
    - `.0.literal` (<- Heading at line 1) must be equal to "Hello World"
    - `.1.level` (<- Heading at line 7) must be equal to 2
    - `.2.literal` (<- Heading at line 13) must be equal to "Examples"
  - Code blocks must pass all the rules
    - `.1` (<- Code block at line 9) must pass the rules
      - "sd" is not a valid code output
    - `.2` (<- Code block at line 15) must pass the rules
      - "asd" is not a valid code output

```

So, lots of complexity here:     
- The validator doesn't stop at the first error and should keep going, eventually displaying all that were found.
- Errors are collected and displayed in a structured manner, showing exactly where each issue occurred.
- Line numbers for each element are included to help locate the issues quickly.


## Building the Validator

We'll start top-down, describing the overall structure and then diving into the specifics of each rule.

```
$validator = v::after(
    get_ast_children(...),
    v::allOf($headingsValidator, $codeBlocksValidator)
);

```

The `get_ast_children(...)` function parses the Markdown file and returns its AST (Abstract Syntax Tree) children. We are going to use the [v::after](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/After.md) validator to validate *the result of that pre-processing*. Our goal is to inspect the syntax tree.

The `v::after()` is actually a hidden gem. It shines when you need to validate and produce messages, but the input is not quite in the format you expect.

We separated our two goals into two more validators, `$headingsValidator` and `$codeBlocksValidator`, to handle each aspect of the Markdown file independently.

This is another handy feature of Respect\Validation: **you can compose the chain** by combining multiple validators into a single expression.

## Validating the Headings

Let's work first on `$headingsValidator`:

```
$headingsValidator = v::after(
    filter_headings(...),
    v::allOf(
        v::key(0, make_heading_validator(level: 1, text: 'Hello World')),
        v::key(1, make_heading_validator(level: 2, text: 'Description')),
        v::key(2, make_heading_validator(level: 2, text: 'Examples')),
    )
);

```

We are using `v::after()` again! This time, to filter the AST using the function `filter_headings(...)`. That function takes a complete AST and returns only the heading elements.

Also, we're now fully embracing composition, and using `make_heading_validator` to create individual validators for each heading in the structure we expect. Here is how that function looks like:

```
function make_heading_validator($level, $text): Validator
{
    return v::shortCircuit(
        v::property('level', v::equals($level)),
        v::property('firstChild', v::property('literal', v::equals($text))),
    );
}
```

It's validating two properties of the AST node. The `level` property ensures the heading level is correct, and the `firstChild.literal` property ensures the heading text matches the expected value.

The [v::shortCircuit](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/ShortCircuit.md) validator stops validation as soon as one of the rules fails, just for that node in the chain, which can improve performance and provide clearer error messages.

## Validating the Code Blocks

Now, let's move on to `$codeBlocksValidator`:

```
$codeBlocksValidator = v::after(
    filter_code_blocks(...),
    v::each(v::allOf(
        v::property('info', v::equals('php')),
        v::property('literal', v::after(
            run_and_capture_output(...),
            v::intVal()
        ))
    ))
);
```

Here we are using another one of my favorites, [v::each](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/Each.md). It applies the given validator to each element in an array. In this case, ensuring that all code block AST nodes have the correct structure and content.

We are also using another function, `run_and_capture_output(...)`, to execute the code blocks and capture their output for validation.

Our validation of the result of these code blocks here is simple, we just want each one to return an integer (checked by `v::intVal`), but we could have gone as far as validating more complex output structures if needed by nesting more validators there.

## First Look at the Messages

So, it's complete, right? Let's see the message output:

```
- `[League\CommonMark\Extension\CommonMark\Node\Block\Heading { -$level=1 #$startLine=1 #$endLine=1 +$data=Dflydev\ ... ]` must pass all the rules
  - `[League\CommonMark\Extension\CommonMark\Node\Block\Heading { -$level=1 #$startLine=1 #$endLine=1 +$data=Dflydev\ ... ]` must pass all the rules
    - `.0.literal` must be equal to "Hello World"
    - `.1.level` must be equal to 2
    - `.2.literal` must be equal to "Examples"
  - Each item in `[League\CommonMark\Extension\CommonMark\Node\Block\FencedCode { -$info="php" -$literal="echo 123;
" -$length=3  ... ]` must be valid
    - `.1` must pass the rules
      - `.1.literal` must be an integer
    - `.2` must pass the rules
      - `.2.literal` must be an integer

```

It kind of works, but the output is a bit verbose and could be more readable. Respect\Validation has many use cases, and it cannot tailor messages for every possible scenario. We instead provide powerful ways of shaping those messages.

## Shaping the Message Output

First, there is something missing. I want the actual lines in the markdown file that produced the error. Can we grab them from the AST and include them in the message in an easy way?

Sure we can! Let's improve the `make_heading_validator` function:

```
function make_heading_validator ($level, $text): Validator
{
    return v::factory(static fn ($heading) => v::named(
        sprintf('Heading at line %s', $heading->getStartLine()),
        v::shortCircuit(
            v::property('level', v::equals($level)),
            v::property('firstChild', v::property('literal', v::equals($text))),
        )
    ));
}

```

If we run it now, we should see some changes:

```
...
- `.0.literal` (<- Heading at line 1) must be equal to "Hello World"
- `.1.level` (<- Heading at line 7) must be equal to 2
- `.2.literal` (<- Heading at line 13) must be equal to "Examples"

```

Cool! We met the acceptance criteria (granular, structured messages with line number output). We can, however, do much better.

We just saw the use of the [v::named](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/Named.md) validator. It isn't a validator per-se, but a way to rename the default name that the engine automatically assigns to each rule. In this case, we're using the line numbers directly in the name as a way to reference them.

By applying `v::named` and `v::templated` to select validator nodes, we can completely change how they're presented, and finally customize the output messages to be more meaningful and readable:

```
- Markdown structure must pass all the rules
  - Heading structure must pass all the rules
    - `.0.literal` (<- Heading at line 1) must be equal to "Hello World"
    - `.1.level` (<- Heading at line 7) must be equal to 2
    - `.2.literal` (<- Heading at line 13) must be equal to "Examples"
  - Code blocks must pass all the rules
    - `.1` (<- Code block at line 9) must pass the rules
      - "sd" is not a valid code output
    - `.2` (<- Code block at line 15) must pass the rules
      - "asd" is not a valid code output

```

## Getting the Code

Check out the [full working code for this example on GitHub](https://github.com/alganet/example-commonmark-respect). I prepared three files in the repository:
- [rawmessages.php](https://github.com/alganet/example-commonmark-respect/blob/main/rawmessages.php) contains the version without message shaping.
- [expressionbuilding.php](https://github.com/alganet/example-commonmark-respect/blob/main/expressionbuilding.php) has the step-by-step construction of the expression.
- [expressionzilla.php](https://github.com/alganet/example-commonmark-respect/blob/main/expressionzilla.php) has the whole expression without intermediate functions or variables, in a single megazilla chain.


## Conclusion

In this article, we explored how to validate the structure of a Markdown document using a single declarative expression with Respect\Validation. We saw how to shape error messages to include line numbers and make them more readable, providing a clear and structured output for easier debugging and validation.

This example clearly demonstrates that Respect\Validation goes way beyond checking simple values, and can perform complex validations on structured data, producing quality error messages that are both informative and easy to understand.

We just launched [Respect\Validation 3.0](https://github.com/Respect/Validation/releases/tag/3.0.0) last week!. Make sure to check it out and explore these new exciting features.
