# Cursor Rules for R Project

## Plan and implementation

- Write plans to the `plans` directory. I want to review plans from a file before they are implemented.

## Coding best practices

- Follow test driven development (red, green, refactor)
- Run `make test` to verify correct functionality before starting to implement a new feature or a new test.
- Write short, focused functions. Refactor existing long functions to shorter functions with descriptive names.
- Use descriptive constants and variables instead of hard-coded integers and strings.
- Use current versions of dependencies. Check public sources to determine the currently available version of a library, package, github action, or other dependency.
- Use existing libraries rather than implementing all functionality from scratch.
- Refactor to DRY rather than repeating logic.
- Refactor for readability rather than only correct functionality.

## Avoid hallucination

- Say "I don't know" if you don't know the answer to a prompt.
- Think before answering.
- Answer only if you are very confident.

## Code Style

- Use tidyverse pipe operator |> for data transformations
- Use snake_case for variable and function names
- Add comments to explain complex logic. Comments explain "why" not "how" or "what".
- Do not add comments that merely repeat values already in the code.
- Group related operations with blank lines before and after
- Use consistent indentation (2 spaces)

## Documentation

- Add a brief description at the top of each R script
- Document any non-obvious data transformations
- Include comments for complex calculations
- Document any assumptions about the data
- Wrap all comments so they are shorter than 80 characters
- Consult the `R` LSP for syntactical warnings and errors

## Data Processing

- Use explicit column names in select() statements
- Group operations logically (filter -> mutate -> arrange)
- Use descriptive variable names
- Handle missing values explicitly

## Visualization

- Use gghighcontrast theme for all plots
- Use InputMono font family for text and labels on all charts
- Include clear titles and labels
- Use consistent color schemes
- Save plots in high resolution (300 DPI)

## File Organization

- Keep test files in fixtures/ directory
- Use descriptive filenames
- Save plots to `plots` directory and original data files to `games` directory.
- Save generated and aggregated data to `data` directory
- Use consistent file naming patterns

## Error Handling

- Validate input data
- Check for missing values
- Handle edge cases explicitly
- Use warning() for non-critical issues

## Performance

- Minimize redundant calculations
- Use efficient data structures
- Avoid unnecessary data copies
- Group operations to reduce iterations

## Version Control

- Keep sensitive data out of version control
- Use .gitignore for temporary files
- Document major changes
- Use `jj` for version control. Do not use `git`
- Keep commits focused and atomic with `jj commit`

## Testing

- Use meaningful test assertions rather than `expect_true` and `expect_false` which result in uninformative failure messages.

## Chat Personality

- When the programmer is speaking about themselves, use "I" not "we"
