# Contributing to Gen IR

Thank you for taking time out of your day to contribute to this project! ❤️

Below, you will find a list of ways you can contribute and how we handle those contributions - it's not exhaustive, so if you run into something that isn't well-defined here we can work together to define it.

## Table of Contents

- [Contributing to Gen IR](#contributing-to-gen-ir)
  - [Table of Contents](#table-of-contents)
  - [Code of Conduct](#code-of-conduct)
  - [Questions](#questions)
  - [Contributions](#contributions)
    - [Reporting Bugs](#reporting-bugs)
      - [Before Submitting a Bug Report](#before-submitting-a-bug-report)
      - [How Do I Submit a Good Bug Report?](#how-do-i-submit-a-good-bug-report)
    - [Suggesting Enhancements](#suggesting-enhancements)
      - [Before Submitting an Enhancement](#before-submitting-an-enhancement)
      - [How Do I Submit a Good Enhancement Suggestion?](#how-do-i-submit-a-good-enhancement-suggestion)
    - [Your First Code Contribution](#your-first-code-contribution)
    - [Improving The Documentation](#improving-the-documentation)
  - [Styleguides](#styleguides)
    - [Commit Messages](#commit-messages)
  - [Attribution](#attribution)

## Code of Conduct

This project adheres to the [Contributor Covenant v2.1](https://www.contributor-covenant.org/).

Everyone participating in the project is expected to adhere to it and uphold the code. Please report unacceptable behavior to <thedderwick@veracode.com>.

## Questions

If you want to ask a question, first make sure you've read the available documentation, searched the internet, as well as any open or closed [Issues](/issues) to see if your question is answered there. If you need clarification on an issue, you can comment on it.

If you still need to ask a question or need clarification on something:

1. Open an [Issue](/issues/new)
2. Provide as much context as you can about what you're running into
3. Provide project and platform versions (Xcode, Compiler, and macOS version), depending on what seems relevant

## Contributions

> ### Legal Notice
>
> When contributing to this project, you must agree that you have authored 100% of the content, that you have the necessary rights to the content and that the content you contribute may be provided under the project license.

### Reporting Bugs

#### Before Submitting a Bug Report

Before making a bug report, make sure you investigate it carefully, collect information, and describe the issue in **detail** in your report. Bug reports containing little to no supporting detail may be closed with no resolution.

A good report shouldn't leave other contributors needing to chase you up or spend a lot of time attempting to reproduce it. Please complete the following steps to help us fix any potential bugs as fast as possible:

- Make sure you are using the latest version.
- Make sure your bug is really a bug
  - Check it's not an incompatible environment, version.
  - Make sure you've read the documentation
  - If you're looking for support - check out [this section](#questions)
- Check if there's an issue relating to this bug in the [bug tracker](/issues?q=label%3Abug)
  - It may already be solved
  - If not, you might be able to add more detail
- Search the internet for the issue
  - It might be an issue outside of the project, or someone else is talking about it elsewhere
- Collect information about the bug:
  - Stack trace (Traceback)
  - OS version & Architecture (x86, ARM64)
  - Version of the compiler, SDK, runtime environment, package manager, depending on what seems relevant.
  - The input and output of the program
  - Can you reliably reproduce the issue? And can you also reproduce it with older versions?
  - If you are able to replicate the bug in a test case, please include it!

#### How Do I Submit a Good Bug Report?

> You must never report security related issues, vulnerabilities or bugs including sensitive information to the issue tracker, or elsewhere in public. Instead please read the [SECURITY.md](SECURITY.md) for guidance on reporting security issues.

We use GitHub issues to track bugs and errors. If you run into an issue with the project:

- Open an [Issue](/issues/new).
- Explain the behavior you would expect and the actual behavior.
- Please provide as much context as possible and describe the *reproduction steps* so that someone else can follow to recreate the issue on their own. This usually includes your code or a reproduction test case. For good bug reports you should isolate the problem and create a reduced test case.
- Provide the information you collected in the previous section.

Once it's filed:

- They will be labelled the issue appropriately by a team member
- A team member will try to reproduce the issue with your provided steps.
  - If there are no reproduction steps or no obvious way to reproduce the issue, the team may ask you for those steps or may close the ticket with no resolution.
  - Bugs that cannot be reproduced will not be addressed until they are reproducible.
- If the team is able to reproduce the issue, it will be tagged, and the issue will be left to be [implemented by someone](#your-first-code-contribution).

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Gen IR, **including completely new features and minor improvements to existing functionality**. Following these guidelines will help maintainers and the community to understand your suggestion and find related suggestions.

#### Before Submitting an Enhancement

- Make sure that you are using the latest version.
- Read the documentation carefully and find out if the functionality is already covered, maybe by an individual configuration.
- Search through [Issues](/issues) to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.
- Find out whether your idea fits with the scope and aims of the project. It's up to you to make a strong case to convince the project's developers of the merits of this feature. Keep in mind that we want features that will be useful to the majority of our users and not just a small subset. If you're just targeting a minority of users, consider writing an add-on/plugin library.

#### How Do I Submit a Good Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub Issues](/issues).

- Use a **clear and descriptive title** for the issue to identify the suggestion.
- Provide a **step-by-step description of the suggested enhancement** in as many details as possible.
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why. At this point you can also tell which alternatives do not work for you.
- You may want to **include screenshots and animated GIFs** which help you demonstrate the steps or point out the part which the suggestion is related to.
- **Explain why this enhancement would be useful** to most Gen IR users. You may also want to point out the other projects that solved it better and which could serve as inspiration.

### Your First Code Contribution

> This section does not cover environment or project setup, see the [README.md](README.md) for building instructions.

Once you've got an idea for your first code contribution, you will need to submit a pull request with your changes.

- Fork the repo, if you haven't already.
- Create a new branch with an **appropriate name** in the forked repo.
- Add your changes, with **sensible commits & commit messages**, to your new branch.
- Open a Pull Request, referencing any open Issues that you may be fixing or working on.

We will review your code changes as soon as possible, and provide feedback if some changes are required.

To reduce review time, please include **detailed** change notes and explain any decisions you've made ahead of time, make sure you check the styleguide below and format your code to it.

### Improving The Documentation

- View any [documentation issues for new contributors](/issues?q=is%3Aopen+label%3A"good+first+issue"+label%3A"documentation") or [other documentation issues](/labels/documentation)
  - If someone else has already been assigned or is working on the issue, look for another one
  - If no one is working on it, or it isn't assigned leave a comment that you want to work on it so no one starts duplicating work
- If you have a change that doesn't have an open Issue, we would still like your contribution!
  - Install some of linters we use: [styleguides](#styleguides) to highlight issues
  - Follow the [Code contribution](#your-first-code-contribution) guide to submit your change

## Styleguides

This project uses [`swiftlint`](https://github.com/realm/SwiftLint) & [`periphery`](https://github.com/peripheryapp/periphery) for Swift code, and [`markdownlint`](https://github.com/DavidAnson/markdownlint) for Markdown files. Please ensure you run them against your changes.

If you think a particular rule doesn't make any sense, we're open to changes! Please add a detailed description for why you think a rule doesn't make sense so it can be discussed.

### Commit Messages

There is no hard rule on commit messages. However, we ask that commit messages should be descriptive to the changes being made. Changes should be broken into logical pieces, and non-descriptive commits should be squashed.

You may be asked to edit your history to be nicer to read.

## Attribution

This guide is loosely based on the **contributing.md**. [Make your own](https://contributing.md/)!
