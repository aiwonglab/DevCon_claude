# Project Name

## Thinking Process

- **Always think through problems** before implementing
- **Consider edge cases** and potential failures
- **Plan the approach** before writing code
- **Identify dependencies** and order of operations

## Tech Stack

- Python: uv environment (`uv run python`)
- [Add your specific technologies here]

## Known Issues

- **UV/Pixi lock file hangs**: If `uv add` or `pixi add` hangs indefinitely, ask user to restart devcontainer
- **Symptoms**: "Updating lock file" message stuck, no progress
- **Solution**: User needs to restart the devcontainer manually

## Code Quality Requirements

- **Type hints required** for all code
- **Public APIs must have docstrings**
- **Line length**: 88 chars maximum
- **PEP 8 naming**: snake_case for functions/variables, PascalCase for classes, UPPER_SNAKE_CASE for constants

## Development Philosophy

- **Simplicity**: Write simple, straightforward code
- **Readability**: Make code easy to understand
- **Performance**: Consider performance without sacrificing readability
- **Maintainability**: Write code that's easy to update
- **Testability**: Ensure code is testable
- **Reusability**: Create reusable components and functions
- **Less Code = Less Debt**: Minimize code footprint

## Code Principles

- **DRY**: Use arguments/variables, not hardcoded values
- **Configurable**: Use arguments and config files
- **Reusable**: Write parameterized, flexible code
- **Early Returns**: Use to avoid nested conditions
- **Descriptive Names**: Use clear variable/function names
- **Functional Style**: Prefer functional, immutable approaches when not verbose
- **Build Iteratively**: Start with minimal functionality and verify it works before adding complexity

## Package Management

- **ONLY use uv**, NEVER pip
- Installation: `uv add package`
- Running tools: `uv run tool`
- Upgrading: `uv add --dev package --upgrade-package package`
- **FORBIDDEN**: `uv pip install`, `@latest` syntax

## Testing Requirements

- Framework: `uv run pytest`
- Async testing: use anyio, not asyncio
- Coverage: test edge cases and errors
- New features require tests
- Bug fixes require regression tests

## Code Formatting & Quality Tools

### Ruff (Required)
- Format: `uv run ruff format .`
- Check: `uv run ruff check .`
- Fix: `uv run ruff check . --fix`
- Critical issues: Line length (88 chars), Import sorting, Unused imports

### Type Checking
- Tool: `uv run pyright`
- Requirements: Explicit None checks for Optional, Type narrowing for strings

### Pre-commit
- Config: `.pre-commit-config.yaml`
- Runs: on git commit
- Tools: Prettier (YAML/JSON), Ruff (Python)

## Git Workflow

### Commit Guidelines
- For bug fixes based on user reports:
  ```bash
  git commit --trailer "Reported-by:<name>"
  ```
- For commits related to GitHub issues:
  ```bash
  git commit --trailer "Github-Issue:#<number>"
  ```
- **NEVER mention** co-authored-by or tool-generated messages

### Pull Requests
- Create detailed message of what changed
- Focus on high-level problem description and solution
- Add appropriate reviewers
- **NEVER mention** co-authored-by or tool-generated aspects

## Error Resolution

### CI Failures Fix Order
1. Formatting (`uv run ruff format .`)
2. Type errors (`uv run pyright`)
3. Linting (`uv run ruff check . --fix`)

### Common Issues
- **Line length**: Break strings with parentheses, multi-line function calls, split imports
- **Types**: Add None checks, narrow string types, match existing patterns
- **Imports**: Remove unused, sort properly

## Project Structure

```
src/                    # Core implementation
├── core/              # Core functionality
├── common/            # Shared utilities
└── [modules]/         # Feature modules
data/                  # Input data
output/                # Generated outputs
tests/                 # Test files
```

## Key Commands

[Add your project-specific commands here]

## Critical Rules

- **Always validate data** before processing
- **Save checkpoints** frequently
- **Test with small samples** before scaling
- **Log all operations** with appropriate detail
- **One codebase** for all scenarios

## Do Not

- Create separate scripts for different sample sizes
- Hardcode values that should be arguments
- Duplicate logic across files
- Skip parameterization
- Copy-paste code instead of refactoring
- Attempt to fix pixi lock hangs (ask for devcontainer restart)

## Important Instruction Reminders

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files unless explicitly requested