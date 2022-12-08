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

- Go to the Actions tab of the homebrew-tap repo
- Choose the `Make Pull Request` workflow
- Run the workflow inputting the tag and revision hash
	- A PR will be created with the change
  - The PR should kick off the `brew test-bot` workflow
- Once `brew test-bot` has completed and you're happy, add the `pr-pull` label
  - Automation will be kicked off to merge, tag, and release the change.

Users can now run `brew update && brew upgrade` to update `gen-ir`
