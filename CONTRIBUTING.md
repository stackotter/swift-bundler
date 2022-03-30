# Contributing

Contributions of all kinds are very welcome! Just make sure to follow the [guidelines](#guidelines) so that your pull requests have the best chance of being accepted.

## Getting started

1. Fork this repository
2. Clone your fork
3. Make changes
4. Open a pull request

## Guidelines

1. Indentation: 2 spaces per indent
2. Add comments to code that you think would need explaining to other contributors
3. Add/update documentation for any code you create/change
4. If a change can be made without introducing breaking changes, don't introduce breaking changes
5. Swift Bundler is programmed in a functional programming style, this means avoid global state and use static functions where possible. This is done to improve reusability of components and to make code easier to reason about
6. Use `Result` instead of `throws` for error handling
7. Each utility should have its own error type (unless it returns no errors)
8. Errors should provide as much context as you think a user would need to understand what happened (if possible)