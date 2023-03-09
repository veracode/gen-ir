# Releasing an Update

When you have an update for `gen-ir`, there's a couple things that need to happen:

- Release a version in the `gen-ir` repo
- Update the version in the `homebrew-tap` repo, so brew picks up the update

## Releasing a gen-ir version

To release a new version of `gen-ir`, create a Pull Request with your changes, ensuring the `build` pipeline finishes successfully, then attach one of the following labels to the PR.

- `merge-bump-major`
  - This will merge the PR & bump a major version (i.e. 1.0.0 to 2.0.0)
- `merge-bump-minor`
	- This will merge the PR & bump a minor version (i.e. 1.0.0 to 1.1.0)
- `merge-bump-patch`
	- This will merge the PR & bump a patch version (i.e. 1.0.0 to 1.0.1)
- `merge-no-bump`
	- This will merge the PR with no version bump

This will merge the PR, bump the version, fix the version in the Versions.swift file, push the commit to main, tag the _new_ commit with the version number, and perform a GitHub release with that tag.

Now, navigate to the release and note the tag name & revision for the next part

## Updating Homebrew Tap

The formula for the tap lives in the [veracode/homebrew-taps](https://github.com/veracode/homebrew-tap) repo. This needs to be updated in order to propagate a new version to users.

- Create a new branch
- Update the gen-ir forumlae's url.tag & url.revision keys to match the release the previous step made
- Open a PR with these changes _and these changes only!_.
	- If any other changes are detected, or more than one commit is made, homebrew's automation will fail
- When checks pass, add the `pr-pull` label to the PR
- Automation will make a new release

Users can now run `brew update && brew upgrade` to update `gen-ir`
