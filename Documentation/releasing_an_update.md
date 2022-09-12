# Releasing an Update

When you have an update for `gen-ir`, there's a couple things that need to happen:

- Release a version in the `gen-ir` repo
- Update the version in the `homebrew-tap` repo, so brew picks up the update

## Releasing a gen-ir version

Currently, there is automation once a version has merged to `main` to handle the updates, tagging, and releasing required for a version. Hopefully, this will eventually be automated into the PR workflow, but for now it sits as a manual action. To kick it off:

- Navigate to the Actions tab of `gen-ir`'s repo
- Under workflows, on the left hand side, select `Release`
- On the right hand side of the workflow run pane, select `Run Workflow`
- Enter the version number you'd like to release

If all goes well, this should:

- Edit the [`Versions.swift`](../Sources/gen-ir/Versions.swift) file with the version being released
- Commit that version change onto `main`
- Create a Release with that tag

Now, navigate to the release and note the tag name & revision for the next part

## Updating Homebrew Tap

The formula for the tap lives in the [NinjaLikesCheez/homebrew-taps](https://github.com/NinjaLikesCheez/homebrew-tap) repo. This needs to be updated in order to propagate a new version to users.

- Clone the `homebrew-taps` repo
- Edit the `tag` & `revision` portion of the `gen-ir` formula
  - Note: _only_ adjust the formula, any other addition will cause the bot to refuse to squash
- Create a PR and let the pipeline run
- When you and the pipeline robot overlords are happy, add the `pr-pull` tag to release
  - This will merge the PR, tag the commit on `main`, and release that commit via GitHub Releases