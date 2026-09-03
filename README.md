# Elm L-trees (kinda)

A program that does iterative replacement and replaces each character in the current pattern with block of characters according to some set of rules. The process may resemble the L-trees system for some rules and patterns.

### Example

Let's define a couple of rules:

```
\
\/
 \

/
 /
/
```

Each rule contains a single character followed by one or more lines those define a "block". Rules are separated by empty lines.

First rule tells that each character `\` will be replaced (substituted) with the block

```
\/
 \
```

Also these general rules always applied:

1. All the blocks should have the same size. Any lesser block will be padded with spaces up to dimestions of the largest block.
2. Any character that doesn't have it's own rule will be substituted with a block of spaces with the same common size.

So, having these rules we can now start from the pattern:

```
\/
```

First evaluation will give us:

```
\/ /
 \/
```

Next step will produce:

```
\/ /   /
 \/   /
  \/ /
   \/
```

And so on. It looks like an L-tree, isn't it!?
