# Contributing to Backup Utility

First off, thank you for considering contributing to this project! We appreciate your time and effort to help improve this tool.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

- Ensure the bug was not already reported by searching on GitHub under [Issues](https://github.com/yourusername/backup-utility/issues).
- If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/yourusername/backup-utility/issues/new). Be sure to include:
  - A clear and descriptive title
  - A description of the expected behavior
  - Steps to reproduce the issue
  - Any relevant error messages
  - Your operating system and version
  - Version of the script you're using

### Suggesting Enhancements

- Use GitHub Issues to submit enhancement suggestions.
- Clearly describe the enhancement and why it would be useful.
- Include any relevant examples or screenshots if applicable.

### Pull Requests

1. Fork the repository and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code follows the style guidelines.
6. Update the CHANGELOG.md with your changes.
7. Issue a Pull Request with a clear list of what you've done.

## Development Setup

### Prerequisites

- Bash 4.0 or higher
- ShellCheck
- shUnit2 (for testing)
- Bats (Bash Automated Testing System)

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/backup-utility.git
   cd backup-utility
   ```
3. Install development dependencies:
   ```bash
   # For Debian/Ubuntu
   sudo apt-get install shellcheck shunit2 bats
   ```

### Testing

Run the test suite:

```bash
# Run ShellCheck for linting
./run_tests.sh lint

# Run unit tests
./run_tests.sh unit

# Run integration tests
./run_tests.sh integration

# Run all tests
./run_tests.sh all
```

## Coding Guidelines

### Shell Script Style Guide

- Use shellcheck to check for common issues
- Use 4 spaces for indentation (no tabs)
- Use `snake_case` for variable and function names
- Use `UPPER_CASE` for environment variables
- Quote all variable expansions
- Prefer `[[` over `[` for tests
- Use `set -euo pipefail` at the beginning of scripts
- Include a shebang line (`#!/bin/bash`)
- Include a header comment with script description and usage
- Document functions with comments
- Use local variables within functions

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally
- Consider starting the commit message with an applicable emoji:
  - ✨ `:sparkles:` when adding a new feature
  - 🐛 `:bug:` when fixing a bug
  - 🔧 `:wrench:` when updating configuration
  - 📝 `:memo:` when writing docs
  - ♻️ `:recycle:` when refactoring code
  - 🚨 `:rotating_light:` when fixing compiler/linter warnings
  - 🔥 `:fire:` when removing code or files

## Review Process

1. A maintainer will review your PR and provide feedback
2. You may be asked to make changes
3. Once approved, a maintainer will merge your PR

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
